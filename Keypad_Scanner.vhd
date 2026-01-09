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
    -- Definición de estados (AQUÍ es donde se declara SCAN)
    type state_type is (SCAN, DEBOUNCE, HOLD_AND_VALID, WAIT_RELEASE);
    signal state : state_type := SCAN;
    
    signal current_row : integer range 0 to 3 := 0;
    signal timer       : integer range 0 to 100000 := 0;
    
    -- Registro interno para mantener el código estable
    signal code_reg    : std_logic_vector(3 downto 0) := x"0";
    
begin
    -- Conectamos el registro a la salida
    key_code <= code_reg;

    process(clk, reset)
    begin
        if reset = '0' then 
            state <= SCAN;
            rows <= "1110"; -- Iniciamos activando fila 0
            current_row <= 0;
            key_valid <= '0';
            code_reg <= x"0";
            timer <= 0;
        elsif rising_edge(clk) then
            case state is
                -- 1. BARRIDO RÁPIDO
                when SCAN =>
                    key_valid <= '0'; -- Por defecto '0' mientras buscamos
                    
                    -- Si detectamos una tecla presionada (alguna columna en 0)
                    if cols /= "1111" then
                        state <= DEBOUNCE;
                        timer <= 0;
                    else
                        -- Siguiente fila (cambio rápido cada 200 ciclos)
                        if timer = 200 then
                            timer <= 0;
                            if current_row = 3 then 
                                current_row <= 0;
                                rows <= "1110"; -- Fila 0
                            else 
                                current_row <= current_row + 1;
                                -- Desplazar el 0 a la siguiente fila
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

                -- 2. FILTRADO DE RUIDO (DEBOUNCE)
                when DEBOUNCE =>
                    timer <= timer + 1;
                    if timer = 50000 then -- Esperar ~1ms
                        if cols /= "1111" then
                            -- Confirmado: Tecla real. Decodificar.
                            state <= HOLD_AND_VALID;
                            
                            -- Lógica de Decodificación
                            if current_row = 0 then
                                if cols(0)='0' then code_reg <= x"D";
                                elsif cols(1)='0' then code_reg <= x"C";
                                elsif cols(2)='0' then code_reg <= x"B";
                                elsif cols(3)='0' then code_reg <= x"A"; end if;
                            elsif current_row = 1 then
                                if cols(0)='0' then code_reg <= x"F"; -- #
                                elsif cols(1)='0' then code_reg <= x"9";
                                elsif cols(2)='0' then code_reg <= x"6";
                                elsif cols(3)='0' then code_reg <= x"3"; end if;
                            elsif current_row = 2 then
                                if cols(0)='0' then code_reg <= x"0";
                                elsif cols(1)='0' then code_reg <= x"8";
                                elsif cols(2)='0' then code_reg <= x"5";
                                elsif cols(3)='0' then code_reg <= x"2"; end if;
                            elsif current_row = 3 then
                                if cols(0)='0' then code_reg <= x"E"; -- *
                                elsif cols(1)='0' then code_reg <= x"7";
                                elsif cols(2)='0' then code_reg <= x"4";
                                elsif cols(3)='0' then code_reg <= x"1"; end if;
                            end if;
                        else
                            -- Falsa alarma
                            state <= SCAN;
                        end if;
                    end if;

                -- 3. ENVIAR DATO Y MANTENER VALID
                when HOLD_AND_VALID =>
                    key_valid <= '1'; -- Activamos la señal para la CPU
                    state <= WAIT_RELEASE;

                -- 4. ESPERAR A QUE SUELTE (Anti-Rebote de salida)
                when WAIT_RELEASE =>
                    -- IMPORTANTE: Mantenemos valid en '1' mientras el usuario presiona.
                    -- Esto da tiempo de sobra a la CPU para leerlo.
                    key_valid <= '1'; 
                    
                    if cols = "1111" then
                        -- El usuario soltó la tecla
                        key_valid <= '0'; 
                        state <= SCAN;
                        timer <= 0;
                    else
                        -- Sigue presionando... esperar
                        state <= WAIT_RELEASE;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;