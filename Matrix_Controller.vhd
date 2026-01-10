library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Matrix_Controller is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic; 
        video_cmd : in  std_logic_vector(7 downto 0); 
        row       : out std_logic_vector(7 downto 0); 
        r         : out std_logic_vector(0 to 7); 
        g         : out std_logic_vector(0 to 7); 
        b         : out std_logic_vector(0 to 7)
    );
end Matrix_Controller;

architecture Behavioral of Matrix_Controller is

    signal contador_reloj : integer range 0 to 50000 := 0;
    signal numero_fila    : integer range 0 to 7 := 0;
    
    signal cmd_type : std_logic_vector(3 downto 0);
    signal cmd_data : integer range 0 to 15;

    type digit_pattern_t is array (0 to 7) of std_logic_vector(7 downto 0);
    signal datos_fila_actual : std_logic_vector(7 downto 0);
    signal patron_seleccionado : digit_pattern_t;

    signal giro_offset : integer range 0 to 7 := 0;
    signal count_anim  : integer range 0 to 5000000 := 0;

    function get_pattern(num : integer) return digit_pattern_t is
    begin
        case num is
            when 0 => return ("00111100", "01100110", "01100110", "01100110", "01100110", "01100110", "00111100", "00000000");
            when 1 => return ("00011000", "00011100", "00011110", "00011000", "00011000", "00011000", "01111110", "00000000");
            when 2 => return ("00111100", "01100110", "00000110", "00001100", "00011000", "00110000", "01111110", "00000000");
            when 3 => return ("00111100", "01100110", "00000110", "00011100", "00000110", "01100110", "00111100", "00000000");
            when 4 => return ("00001100", "00011100", "00101100", "01001100", "11111110", "00001100", "00001100", "00000000");
            when 5 => return ("01111110", "01000000", "01111100", "00000110", "00000110", "01100110", "00111100", "00000000");
            when 6 => return ("00111100", "01100110", "01000000", "01111100", "01100110", "01100110", "00111100", "00000000");
            when 7 => return ("01111110", "00000110", "00001100", "00011000", "00110000", "00110000", "00110000", "00000000");
            when 8 => return ("00111100", "01100110", "01100110", "00111100", "01100110", "01100110", "00111100", "00000000");
            when 9 => return ("00111100", "01100110", "01100110", "00111110", "00000110", "01100110", "00111100", "00000000");
            -- 10: Letra 'A'
            when 10 => return ("00011000", "00111100", "01100110", "01100110", "01111110", "01100110", "01100110", "00000000");
            -- 11: Letra 'b'
            when 11 => return ("01000000", "01000000", "01000000", "01111100", "01100110", "01100110", "01111100", "00000000");
            -- 12: Letra 'C'
            when 12 => return ("00111100", "01100110", "01100000", "01100000", "01100000", "01100110", "00111100", "00000000");
            when others => return ("10000001", "01000010", "00100100", "00011000", "00011000", "00100100", "01000010", "10000001");
        end case;
    end function;

begin
    
    cmd_type <= video_cmd(7 downto 4);
    cmd_data <= to_integer(unsigned(video_cmd(3 downto 0)));

    -- 1. Selección de Patrón
    process(cmd_type, cmd_data, giro_offset)
    begin
        case cmd_type is
            when x"1" => -- MENU 
                 patron_seleccionado <= get_pattern(10);
            when x"5" => -- RESULTADO 
                 patron_seleccionado <= get_pattern(cmd_data);
            when x"4" => -- GIRO 
                 for i in 0 to 7 loop
                    if i = giro_offset then 
                       patron_seleccionado(i) <= "11111111"; 
                    else 
                        patron_seleccionado(i) <= "00000000";
                    end if;
                 end loop;
            when others => 
                 patron_seleccionado <= (others => (others => '0'));
        end case;
    end process;

    -- 2. Divisor de Frecuencia y Animación
    process(clk)
    begin
        if rising_edge(clk) then
            -- Mux de Filas
            if contador_reloj = 5000 then 
                contador_reloj <= 0;
                if numero_fila = 7 then numero_fila <= 0; else numero_fila <= numero_fila + 1; end if;
            else
                contador_reloj <= contador_reloj + 1;
            end if;
            
            -- Animación de Giro
            if cmd_type = x"4" then
                if count_anim = 1000000 then 
                    count_anim <= 0;
                    if giro_offset = 7 then giro_offset <= 0; else giro_offset <= giro_offset + 1; end if;
                else
                    count_anim <= count_anim + 1;
                end if;
            end if;
        end if;
    end process;

    -- 3. Activar Fila Física
    process(numero_fila)
    begin
        row <= (others => '0');
        row(numero_fila) <= '1'; 
    end process;

    -- 4. Lógica de Color
    datos_fila_actual <= patron_seleccionado(numero_fila);

    process(numero_fila, cmd_type, cmd_data, datos_fila_actual)
        variable num_int : integer;
        variable es_rojo : boolean;
    begin
        r <= (others => '1');
        g <= (others => '1'); 
        b <= (others => '1');

        case cmd_type is
            when x"2" => -- Selección de Color
                if numero_fila < 2 then      -- Rojo
                     r <= x"00";
                elsif numero_fila < 5 then   -- Azul
                    b <= x"00";
                else                         -- Verde
                    g <= x"00";
                end if;

            when x"5" => -- Resultado
                num_int := cmd_data;
                
                if (num_int = 2 or num_int = 4 or num_int = 6 or num_int = 8) then
                    es_rojo := true;
                else
                    es_rojo := false;
                end if;

                for col in 0 to 7 loop
                    if datos_fila_actual(col) = '1' then
                        r(col) <= '0';
                        g(col) <= '0'; 
                        b(col) <= '0'; 
                    else
                        -- Fondo
                        if num_int = 0 then       -- Verde
                            g(col) <= '0';
                        elsif es_rojo then        -- Rojo
                            r(col) <= '0';
                        else                      -- Azul
                            b(col) <= '0';
                        end if;
                    end if;
                end loop;

            when others => -- Menú y Giro
                for col in 0 to 7 loop
                    if datos_fila_actual(col) = '1' then
                        r(col) <= '0';
                        g(col) <= '0'; 
                        b(col) <= '0';
                    end if;
                end loop;
        end case;
    end process;

end Behavioral;