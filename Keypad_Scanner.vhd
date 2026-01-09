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
    -- AGREGAMOS UN NUEVO ESTADO: RELEASE_WAIT
    type state_type is (SCAN, DEBOUNCE, PRESSED, RELEASE_WAIT);
    signal state : state_type := SCAN;
    
    signal current_row : integer range 0 to 3 := 0;
    signal count       : integer range 0 to 50000 := 0; 
    
begin

    process(clk, reset)
    begin
        if reset = '0' then 
            state <= SCAN;
            rows <= "1111";
            key_valid <= '0';
            key_code <= x"0";
        elsif rising_edge(clk) then
            case state is
                when SCAN =>
                    key_valid <= '0';
                    -- Barrido constante
                    case current_row is
                        when 0 => rows <= "1110";
                        when 1 => rows <= "1101";
                        when 2 => rows <= "1011";
                        when 3 => rows <= "0111";
                        when others => rows <= "1111";
                    end case;
                    
                    -- Si detectamos algo (AL MENOS UN CERO)
                    if cols /= "1111" then
                        state <= DEBOUNCE;
                        count <= 0;
                    else
                        -- Velocidad de barrido
                        if count = 5000 then 
                            count <= 0;
                            if current_row = 3 then current_row <= 0; else current_row <= current_row + 1; end if;
                        else
                            count <= count + 1;
                        end if;
                    end if;
                    
                when DEBOUNCE =>
                    if count = 50000 then 
                        -- Confirmamos si sigue presionado
                        if cols /= "1111" then
                            state <= PRESSED;
                            key_valid <= '1'; -- ¡VALIDAMOS LA TECLA!
                            
                            -- TU MAPEO CORRECTO:
                            if current_row = 0 then
                                if cols(0)='0' then key_code <= x"D";
                                elsif cols(1)='0' then key_code <= x"C";
                                elsif cols(2)='0' then key_code <= x"B";
                                elsif cols(3)='0' then key_code <= x"A";
                                end if;
                            elsif current_row = 1 then
                                if cols(0)='0' then key_code <= x"F"; -- #
                                elsif cols(1)='0' then key_code <= x"9";
                                elsif cols(2)='0' then key_code <= x"6";
                                elsif cols(3)='0' then key_code <= x"3";
                                end if;
                            elsif current_row = 2 then
                                if cols(0)='0' then key_code <= x"0";
                                elsif cols(1)='0' then key_code <= x"8";
                                elsif cols(2)='0' then key_code <= x"5";
                                elsif cols(3)='0' then key_code <= x"2";
                                end if;
                            elsif current_row = 3 then
                                if cols(0)='0' then key_code <= x"E"; -- *
                                elsif cols(1)='0' then key_code <= x"7";
                                elsif cols(2)='0' then key_code <= x"4";
                                elsif cols(3)='0' then key_code <= x"1";
                                end if;
                            end if;
                        else
                            state <= SCAN; -- Falsa alarma
                        end if;
                    else
                        count <= count + 1;
                    end if;
                    
                when PRESSED =>
                    -- Esperar a que suelte la tecla ("1111")
                    if cols = "1111" then
                        -- En lugar de ir a SCAN directo, vamos a verificar que sea verdad
                        state <= RELEASE_WAIT;
                        count <= 0;
                    end if;

                -- NUEVO ESTADO PARA EVITAR QUE SE PEGUE
                when RELEASE_WAIT =>
                    if count = 50000 then -- Esperamos un momento (~1ms)
                        if cols = "1111" then
                            state <= SCAN; -- Ahora sí, seguro soltó la tecla
                        else
                            state <= PRESSED; -- Falso, rebotó y sigue presionada
                        end if;
                    else
                        count <= count + 1;
                    end if;

            end case;
        end if;
    end process;
end Behavioral;