import RPi.GPIO as GPIO
import time

# 1. Setup GPIO Mode
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# 2. Pin Definitions 
S_PINS = [17, 27, 22, 23]      # S0, S1, S2, S3
MUX_SIG_PINS = [5, 6, 13, 19]  # MUX1, MUX2, MUX3, MUX4

# Setup Pins
for pin in S_PINS:
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.LOW)

for pin in MUX_SIG_PINS:
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

def set_mux_channel(channel):
    """Btzbot el S0-S3 3ashan t-select channel"""
    for i in range(4):
        bit = (channel >> i) & 1
        GPIO.output(S_PINS[i], bit)

def read_raw_board():
    """Btrg3 list bel (mux_index, channel) elly 3alehom magnet waqt el scan"""
    active_sensors = []
    for channel in range(16):
        set_mux_channel(channel)
        time.sleep(0.01) # Delay l man3 el ghosting
        for mux_index, sig_pin in enumerate(MUX_SIG_PINS):
            if GPIO.input(sig_pin) == GPIO.LOW:
                active_sensors.append((mux_index, channel))
    return active_sensors

def generate_squares_list():
    """Bt3mel generate l asamy el 64 morba3 (a1 to h8)"""
    files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
    ranks = ['1', '2', '3', '4', '5', '6', '7', '8']
    squares = []
    for rank in ranks:
        for file in files:
            squares.append(f"{file}{rank}")
    return squares

def run_calibration():
    # Hnbd2 el map kolo b None (elly hya Null f Python)
    new_map = {0: [None]*16, 1: [None]*16, 2: [None]*16, 3: [None]*16}
    squares_to_map = generate_squares_list()
    
    print("========================================")
    print("       Chess Mate Calibration Tool      ")
    print("========================================")
    print("Et2aked en el ro23a fadya 5ales mn ay 2eta3.")
    print("Law 3aiz te-skip ay morba3, ektb 'null' w doos Enter.")
    print("========================================\n")
    
    for square in squares_to_map:
        mapped_successfully = False
        
        while not mapped_successfully:
            print(f"---> Morba3: ** {square.upper()} **")
            user_input = input("7ot el magnet w doos 'Enter' (aw ektb 'null' 3ashan t-skip): ").strip().lower()
            
            # Law el user katab null
            if user_input == 'null':
                print(f"  [-] Tmm, 3adena morba3 {square.upper()} w hysht8al ka Null.\n")
                break # By-exit el while loop w y5osh 3al morba3 elly b3do
            
            # Law das Enter bas, n2ra el ro23a
            active = read_raw_board()
            
            if len(active) == 1:
                mux_idx, ch = active[0]
                
                # Check law el pin da t3mlo assign abl kda (3ashan my7slsh overwrite bl 8alat)
                if new_map[mux_idx][ch] is not None:
                    print(f"  [!] TAHZEER: El pin da mt-saial abal kda 3ala {new_map[mux_idx][ch]}!")
                
                new_map[mux_idx][ch] = square
                print(f"  [v] Tmm! Map {square} -> MUX {mux_idx + 1}, Channel {ch}\n")
                mapped_successfully = True
                
            elif len(active) == 0:
                print("  [X] Mafesh ay sensor 2ara! (Et2kd en el magnet mwgod w metwasal sa7).")
            else:
                print(f"  [X] Ana 2ary {len(active)} sensors sha8aleen m3 ba3d! (Shyl ay magnet tany w et2kd mn el 2afla).")

    # Print the final dictionary
    print("\n\n========================================")
    print("          CALIBRATION COMPLETE          ")
    print("========================================")
    print("5od el block da Copy w e3melo Paste f code el main bta3ak:\n")
    
    print("CHESS_MAP = {")
    for mux_idx in range(4):
        # Ben-format el list 3ashan ttba3 sa7 b None mn 8er strings
        formatted_list = [f"'{x}'" if x is not None else "None" for x in new_map[mux_idx]]
        print(f"    {mux_idx}: [{', '.join(formatted_list)}],")
    print("}")
    
if __name__ == '__main__':
    try:
        run_calibration()
    except KeyboardInterrupt:
        print("\nExiting Calibration...")
    finally:
        GPIO.cleanup()
