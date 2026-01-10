library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Keypad_Scanner is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        rows      : out std_logic_vector(3 downto 0);
        cols      : in  std_logic_vector(3 downto 0);
        key_code  : out std_logic_vector(3 downto 0);
        key_valid : out std_logic
    );
end Keypad_Scanner;

architecture Behavioral of Keypad_Scanner is
    type state_type is (SCAN, DEBOUNCE, HOLD_AND_VALID, WAIT_RELEASE);
    signal state : state_type := SCAN;
    
    signal current_row : integer range 0 to 3 := 0;
    signal timer       : integer range 0 to 100000 := 0;
    signal code_reg    : std_logic_vector(3 downto 0) := x"0";
begin
    
    key_code <= code_reg;

    process(clk, reset)
    begin
        if reset = '0' then 
            state <= SCAN;
            rows <= "1110"; 
            current_row <= 0;
            key_valid <= '0';
            code_reg <= x"0";
            timer <= 0;
        elsif rising_edge(clk) then
            case state is
                -- 1. BARRIDO RÁPIDO
                when SCAN =>
                    key_valid <= '0';
                    if cols /= "1111" then
                        state <= DEBOUNCE;
                        timer <= 0;
                    else
                        if timer = 200 then
                            timer <= 0;
                            if current_row = 3 then 
                                current_row <= 0;
                                rows <= "1110"; 
                            else 
                                current_row <= current_row + 1;
                                case current_row + 1 is
                                    when 1 => rows <= "1101";
                                    when 2 => rows <= "1011";
                                    when 3 => rows <= "0111";
                                    when others => rows <= "1111";
                                end case;
                            end if;
                        else
                            timer <= timer + 1;
                        end if;
                    end if;

                -- 2. FILTRADO DE RUIDO
                when DEBOUNCE =>
                    timer <= timer + 1;
                    if timer = 50000 then 
                        if cols /= "1111" then
                            state <= HOLD_AND_VALID;
                            
                            -- Decodificación
                            if current_row = 0 then
                                if cols(0)='0' then code_reg <= x"D";
                                elsif cols(1)='0' then code_reg <= x"C";
                                elsif cols(2)='0' then code_reg <= x"B";
                                elsif cols(3)='0' then code_reg <= x"A"; end if;
                            elsif current_row = 1 then
                                if cols(0)='0' then code_reg <= x"F";
                                elsif cols(1)='0' then code_reg <= x"9";
                                elsif cols(2)='0' then code_reg <= x"6";
                                elsif cols(3)='0' then code_reg <= x"3"; end if;
                            elsif current_row = 2 then
                                if cols(0)='0' then code_reg <= x"0";
                                elsif cols(1)='0' then code_reg <= x"8";
                                elsif cols(2)='0' then code_reg <= x"5";
                                elsif cols(3)='0' then code_reg <= x"2"; end if;
                            elsif current_row = 3 then
                                if cols(0)='0' then code_reg <= x"E";
                                elsif cols(1)='0' then code_reg <= x"7";
                                elsif cols(2)='0' then code_reg <= x"4";
                                elsif cols(3)='0' then code_reg <= x"1"; end if;
                            end if;
                        else
                            state <= SCAN;
                        end if;
                    end if;

                -- 3. ENVIAR DATO
                when HOLD_AND_VALID =>
                    key_valid <= '1';
                    state <= WAIT_RELEASE;

                -- 4. ESPERAR A QUE SUELTE
                when WAIT_RELEASE =>
                    key_valid <= '1';
                    if cols = "1111" then
                        key_valid <= '0';
                        state <= SCAN;
                        timer <= 0;
                    else
                        state <= WAIT_RELEASE;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;