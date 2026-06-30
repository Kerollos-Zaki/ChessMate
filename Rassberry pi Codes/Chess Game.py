import RPi.GPIO as GPIO
import time
import chess
import chess.engine
import firebase_admin 
from firebase_admin import credentials, db 
import serial

# ==========================================
# 0. FIREBASE INITIALIZATION
# ==========================================
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://chessmate-4e542-default-rtdb.europe-west1.firebasedatabase.app/'
})
ref = db.reference('/')

# ==========================================
# 1. SETUP STOCKFISH ENGINE
# ==========================================
STOCKFISH_PATH = "/usr/games/stockfish"

try:
    stockfish = chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)
    print("[v] Stockfish Engine Loaded Successfully!")
except Exception as e:
    print(f"[X] Error loading Stockfish: {e}")
    print("Make sure the Stockfish path is correct and that it is installed.")
    exit()

# ==========================================
# 2. UART (SERIAL TO ARDUINO) SETUP
# ==========================================
SERIAL_PORT = "/dev/ttyUSB0" # Change to /dev/ttyUSB0 if needed
BAUD_RATE = 9600

try:
    arduino = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    print(f"[v] Serial connection to Arduino established on {SERIAL_PORT}")
    time.sleep(2) # Give Arduino time to reboot
except Exception as e:
    print(f"[X] Error connecting to Arduino: {e}")
    print("Make sure the Arduino is connected via USB.")
    # You can comment out exit() if you want to test without the Arduino plugged in
    exit()

# ==========================================
# 3. GPIO & PINS SETUP
# ==========================================
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

S_PINS = [17, 27, 22, 23]
MUX_SIG_PINS = [5, 6, 13, 19]

for pin in S_PINS:
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.LOW)

for pin in MUX_SIG_PINS:
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# ==========================================
# 4. CHESS MAP & LOGIC
# ==========================================
CHESS_MAP = {
    0: ['h1', 'h3', 'h5', 'h7', 'g1', 'g3', 'g5', 'g7', 'g8', 'g6', 'g4', 'g2', 'h8', 'h6', 'h4', 'h2'],
    1: ['f1', 'f3', 'f5', 'f7', 'e1', 'e3', 'e5', 'e7', 'e8', 'e6', 'e4', 'e2', 'f8', 'f6', 'f4', 'f2'],
    2: ['d1', 'd3', 'd5', 'd7', 'c1', 'c3', 'c5', 'c7', 'c8', 'c6', 'c4', 'c2', 'd8', 'd6', 'd4', 'd2'],
    3: ['b1', 'b3', 'b5', 'b7', 'a1', 'a3', 'a5', 'a7', 'a8', 'a6', 'a4', 'a2', 'b8', 'b6', 'b4', 'b2'],
}

def set_mux_channel(channel):
    for i in range(4):
        GPIO.output(S_PINS[i], (channel >> i) & 1)

def read_physical_board():
    occupied_squares = []
    for channel in range(16):
        set_mux_channel(channel)
        time.sleep(0.005)
        for mux_index, sig_pin in enumerate(MUX_SIG_PINS):
            if GPIO.input(sig_pin) == GPIO.LOW:
                square_name = CHESS_MAP[mux_index][channel]
                if square_name is not None:
                    occupied_squares.append(square_name)
    return set(occupied_squares)

def get_stable_board_state(stable_duration=1.0):
    current_state = read_physical_board()
    start_time = time.time()
    while True:
        time.sleep(0.1)
        new_state = read_physical_board()
        if new_state != current_state:
            current_state = new_state
            start_time = time.time()
        elif time.time() - start_time >= stable_duration:
            return current_state

def infer_move(board, previous_squares, current_squares):
    missing = list(previous_squares - current_squares)
    added   = list(current_squares - previous_squares)

    if len(missing) == 1 and len(added) == 1:
        return missing[0] + added[0]
    elif len(missing) == 1 and len(added) == 0:
        origin_square = missing[0]
        for legal_move in board.legal_moves:
            if legal_move.uci().startswith(origin_square) and board.is_capture(legal_move):
                return legal_move.uci()
    return None

def get_expected_physical_board(board):
    """Generates the expected physical board state from the engine."""
    occupied = set()
    for square in chess.SQUARES:
        if board.piece_at(square):
            occupied.add(chess.square_name(square))
    return occupied

# ==========================================
# 5. HELPERS & COMMUNICATION
# ==========================================
def get_ai_depth_from_firebase():
    """Reads the intended search depth from Firebase (1-20)."""
    try:
        depth = db.reference('settings/ai_depth').get()
        if depth is not None:
            return int(depth)
    except Exception as e:
        print(f"[!] Error reading AI depth from Firebase: {e}")
    return 5 

def send_to_arduino(uci_move, label):
    """Sends coordinates via UART. Only triggers for the AI."""
    files = {f: i + 1 for i, f in enumerate('abcdefgh')}
    x1, y1 = files[uci_move[0]], int(uci_move[1])
    x2, y2 = files[uci_move[2]], int(uci_move[3])
    
    # \n is crucial so the Arduino knows the message is finished
    command = f"{x1},{y1},{x2},{y2}\n"
    print(f"[->] {label} Move Coordinates: {x1},{y1},{x2},{y2} (From {uci_move[0:2]} to {uci_move[2:4]})")
    
    # ONLY send to Arduino if it is Stockfish moving
    if label == "STOCKFISH" and 'arduino' in globals() and arduino.is_open:
        arduino.write(command.encode('utf-8'))

def print_fancy_board(board):
    print("\n    a b c d e f g h")
    print("  +-----------------+")
    rows = str(board).split('\n')
    for i, row in enumerate(rows):
        print(f"{8-i} | {row} | {8-i}")
    print("  +-----------------+")
    print("    a b c d e f g h\n")

# ==========================================
# MAIN GAME LOOP
# ==========================================
if __name__ == '__main__':
    engine_board = chess.Board()

    print("=============================================")
    print("  ChessMate VS Stockfish AI (Live Visualizer)")
    print("=============================================")
    print(f"[START] Initial FEN: {engine_board.fen()}")
    
    ref.update({
        'game_state/fen': engine_board.fen(),
        'game_state/last_move': 'start'
    })

    print_fancy_board(engine_board)
    print("Start playing (White moves first)...\n")

    try:
        previous_squares = get_stable_board_state()

        while True:
            current_squares = get_stable_board_state(stable_duration=1.0)

            if current_squares != previous_squares:
                guessed_move_uci = infer_move(engine_board, previous_squares, current_squares)

                if guessed_move_uci:
                    move = chess.Move.from_uci(guessed_move_uci)

                    if move in engine_board.legal_moves:
                        # --- 1. USER MOVE ---
                        engine_board.push(move)
                        current_fen = engine_board.fen()

                        ref.update({
                            'game_state/fen': current_fen,
                            'game_state/last_move': guessed_move_uci
                        })

                        print("=============================================")
                        print(f"[+] USER Move Detected: {guessed_move_uci}")
                        send_to_arduino(guessed_move_uci, "USER")  
                        print(f"[>] New FEN: {current_fen}")
                        print_fancy_board(engine_board)

                        # --- 2. STOCKFISH CONFIGURATION & MOVE ---
                        current_ai_depth = get_ai_depth_from_firebase()
                        
                        # Apply Skill Level (max 20) alongside Depth for human-like play
                        stockfish.configure({"Skill Level": min(current_ai_depth, 20)})

                        print(f"[🤖] Stockfish is thinking... (Depth: {current_ai_depth})")
                        result = stockfish.play(engine_board, chess.engine.Limit(depth=current_ai_depth))
                        best_move_uci = result.move.uci()
                        
                        engine_board.push(result.move)
                        
                        ref.update({
                            'game_state/fen': engine_board.fen(),
                            'game_state/last_move': best_move_uci
                        })

                        print(f"[🔥] Stockfish Best Move: {best_move_uci}")
                        # This command physically triggers the Arduino!
                        send_to_arduino(best_move_uci, "STOCKFISH") 
                        print_fancy_board(engine_board)
                        print("=============================================\n")

                        # --- 3. HARDWARE SYNCHRONIZATION ---
                        expected_physical_state = get_expected_physical_board(engine_board)
                        
                        print("⏳ Arduino is moving the piece... Waiting for hardware confirmation...")
                        
                        # Wait until the reed switches confirm the piece has arrived
                        while True:
                            check_state = get_stable_board_state(stable_duration=0.5)
                            if check_state == expected_physical_state:
                                print("[✅] Stockfish's move confirmed on the physical board!")
                                break
                            time.sleep(0.5) 
                            
                        # Reset the baseline memory so you can make your next move
                        previous_squares = expected_physical_state
                        print("\n[+] Your turn! Make your move...")
                        
                    else:
                        print(f"[-] Hardware Error: {guessed_move_uci} is NOT a legal move! Return the piece to its original square.")
                else:
                    print("[-] Hardware Error: Reading confusion. Return pieces to original squares and move clearly.")

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\nExiting Game Tracker...")
    finally:
        GPIO.cleanup()
        stockfish.quit()
        if 'arduino' in globals() and arduino.is_open:
            arduino.close()
        print("Stockfish Engine and Serial Port Closed.")
