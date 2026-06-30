import RPi.GPIO as GPIO
import time

# 1. Setup GPIO Mode
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# 2. Pin Definitions 
S_PINS = [17, 27, 22, 23]
MUX_SIG_PINS = [5, 6, 13, 19]

for pin in S_PINS:
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.LOW)

for pin in MUX_SIG_PINS:
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# 3. Mapping the Board (Fully Calibrated)
CHESS_MAP = {
    0: ['h1', 'h3', 'h5', 'h7', 'g1', 'g3', 'g5', 'g7', 'g8', 'g6', 'g4', 'g2', 'h8', 'h6', 'h4', 'h2'],
    1: ['f1', 'f3', 'f5', 'f7', 'e1', 'e3', 'e5', 'e7', 'e8', 'e6', 'e4', 'e2', 'f8', 'f6', 'f4', 'f2'],
    2: ['d1', 'd3', 'd5', 'd7', 'c1', 'c3', 'c5', 'c7', 'c8', 'c6', 'c4', 'c2', 'd8', 'd6', 'd4', 'd2'],
    3: ['b1', 'b3', 'b5', 'b7', 'a1', 'a3', 'a5', 'a7', 'a8', 'a6', 'a4', 'a2', 'b8', 'b6', 'b4', 'b2'],
}

# 4. FULL Standard Starting Position (All 32 Pieces, including C and D)
STARTING_POSITION = {
    # White
    'a1': 'White Rook', 'b1': 'White Knight', 'c1': 'White Bishop', 'd1': 'White Queen',
    'e1': 'White King', 'f1': 'White Bishop', 'g1': 'White Knight', 'h1': 'White Rook',
    'a2': 'White Pawn', 'b2': 'White Pawn', 'c2': 'White Pawn', 'd2': 'White Pawn',
    'e2': 'White Pawn', 'f2': 'White Pawn', 'g2': 'White Pawn', 'h2': 'White Pawn',
    
    # Black
    'a7': 'Black Pawn', 'b7': 'Black Pawn', 'c7': 'Black Pawn', 'd7': 'Black Pawn',
    'e7': 'Black Pawn', 'f7': 'Black Pawn', 'g7': 'Black Pawn', 'h7': 'Black Pawn',
    'a8': 'Black Rook', 'b8': 'Black Knight', 'c8': 'Black Bishop', 'd8': 'Black Queen',
    'e8': 'Black King', 'f8': 'Black Bishop', 'g8': 'Black Knight', 'h8': 'Black Rook'
}

EXPECTED_SQUARES = set(STARTING_POSITION.keys())

PIECE_TO_FEN = {
    'White Pawn': 'P', 'White Knight': 'N', 'White Bishop': 'B', 'White Rook': 'R', 'White Queen': 'Q', 'White King': 'K',
    'Black Pawn': 'p', 'Black Knight': 'n', 'Black Bishop': 'b', 'Black Rook': 'r', 'Black Queen': 'q', 'Black King': 'k'
}

def generate_fen(board_state):
    """By7awel el dictionary bta3 el ro23a l FEN string standard"""
    fen_rows = []
    
    for rank in range(8, 0, -1):
        empty_count = 0
        row_str = ""
        for file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']:
            square = f"{file}{rank}"
            if square in board_state:
                if empty_count > 0:
                    row_str += str(empty_count)
                    empty_count = 0
                row_str += PIECE_TO_FEN[board_state[square]]
            else:
                empty_count += 1
                
        if empty_count > 0:
            row_str += str(empty_count)
            
        fen_rows.append(row_str)
        
    board_fen = "/".join(fen_rows)
    return f"{board_fen} w KQkq - 0 1"

def set_mux_channel(channel):
    for i in range(4):
        bit = (channel >> i) & 1
        GPIO.output(S_PINS[i], bit)

def read_board():
    occupied_squares = []
    for channel in range(16):
        set_mux_channel(channel)
        time.sleep(0.01)
        for mux_index, sig_pin in enumerate(MUX_SIG_PINS):
            state = GPIO.input(sig_pin)
            if state == GPIO.LOW:  
                square_name = CHESS_MAP[mux_index][channel]
                if square_name is not None:
                    occupied_squares.append(square_name)
    return set(occupied_squares) 

def check_initial_setup():
    current_squares = read_board()
    
    missing_pieces = EXPECTED_SQUARES - current_squares
    extra_pieces = current_squares - EXPECTED_SQUARES
    
    return missing_pieces, extra_pieces, current_squares

# 5. Main Loop 
if __name__ == '__main__':
    try:
        print("Babd2 Test el Ro23a Kamla...")
        game_ready = False
        
        while not game_ready:
            missing, extra, current = check_initial_setup()
            
            if not missing and not extra:
                print("\n[+] Perfect! El 32 2et3a mtrsaseen sa7.")
                
                active_board_state = {sq: STARTING_POSITION[sq] for sq in current if sq in STARTING_POSITION}
                
                current_fen = generate_fen(active_board_state)
                
                print(f"\n[>] FEN String: {current_fen}")
                game_ready = True
                
            else:
                print("\n[-] El Rassa feha 7aga msh mazboota:")
                if missing:
                    print(f"    -> Na2es 2eta3 3ala: {sorted(list(missing))}")
                if extra:
                    print(f"    -> Shel el 2eta3 di mn 3ala: {sorted(list(extra))}")
                    
                time.sleep(1.5) 
                
    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        GPIO.cleanup()
