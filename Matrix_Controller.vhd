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

    -- Señales para la animación de ruleta
    signal ruleta_offset : integer range 0 to 23 := 0;  -- 24 posiciones = 8 cols x 3 colores
    signal count_anim    : integer range 0 to 5000000 := 0;
    signal velocidad_actual : integer range 0 to 5000000 := 200000;  -- Velocidad dinámica
    signal tiempo_giro : integer range 0 to 100 := 0;  -- Contador de pasos para desaceleración
    
    -- Señales para animación de victoria
    signal victoria_parpadeo : std_logic := '0';
    signal count_parpadeo : integer range 0 to 10000000 := 0;

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
            -- 13: X (para cuando pierde)
            when 13 => return ("11000011", "01100110", "00111100", "00011000", "00111100", "01100110", "11000011", "00000000");
            when others => return ("10000001", "01000010", "00100100", "00011000", "00011000", "00100100", "01000010", "10000001");
        end case;
    end function;

begin
    
    cmd_type <= video_cmd(7 downto 4);
    cmd_data <= to_integer(unsigned(video_cmd(3 downto 0)));

    -- 1. Selección de Patrón
    process(cmd_type, cmd_data)
    begin
        case cmd_type is
            when x"1" => -- MENU 
                 patron_seleccionado <= get_pattern(10);
            when x"5" => -- RESULTADO 
                 patron_seleccionado <= get_pattern(cmd_data);
            when x"4" => -- GIRO - Todos los LEDs encendidos para la ruleta
                 patron_seleccionado <= (others => "11111111");
            when x"6" => -- ANIMACIÓN DE VICTORIA - Patrón intermitente
                 patron_seleccionado <= (others => "11111111");
            when x"7" => -- ANIMACIÓN DE DERROTA - Mostrar X
                 patron_seleccionado <= get_pattern(13);
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
            
            -- Animación de Ruleta con DESACELERACIÓN PROGRESIVA
            if cmd_type = x"4" then
                if count_anim >= velocidad_actual then
                    count_anim <= 0;
                    
                    -- Avanzar la animación
                    if ruleta_offset = 23 then 
                        ruleta_offset <= 0; 
                    else 
                        ruleta_offset <= ruleta_offset + 1; 
                    end if;
                    
                    -- Incrementar el contador de tiempo de giro
                    if tiempo_giro < 100 then
                        tiempo_giro <= tiempo_giro + 1;
                    end if;
                    
                    -- DESACELERACIÓN GRADUAL en 4 etapas
                    if tiempo_giro < 15 then
                        -- Etapa 1: MUY RÁPIDO (primeros pasos)
                        velocidad_actual <= 200000;
                    elsif tiempo_giro < 35 then
                        -- Etapa 2: RÁPIDO
                        velocidad_actual <= 400000;
                    elsif tiempo_giro < 60 then
                        -- Etapa 3: MEDIO
                        velocidad_actual <= 800000;
                    elsif tiempo_giro < 85 then
                        -- Etapa 4: LENTO
                        velocidad_actual <= 1500000;
                    else
                        -- Etapa 5: MUY LENTO (casi parando)
                        velocidad_actual <= 3000000;
                    end if;
                else
                    count_anim <= count_anim + 1;
                end if;
            else
                -- Reiniciar cuando NO estamos en modo giro
                count_anim <= 0;
                tiempo_giro <= 0;
                velocidad_actual <= 200000;
                ruleta_offset <= 0;
            end if;
            
            -- Animación de VICTORIA (parpadeo rápido)
            if cmd_type = x"6" then
                if count_parpadeo = 2000000 then  -- Parpadeo cada ~0.04 segundos
                    count_parpadeo <= 0;
                    victoria_parpadeo <= not victoria_parpadeo;
                else
                    count_parpadeo <= count_parpadeo + 1;
                end if;
            else
                count_parpadeo <= 0;
                victoria_parpadeo <= '0';
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

    process(numero_fila, cmd_type, cmd_data, datos_fila_actual, ruleta_offset, victoria_parpadeo)
        variable num_int : integer;
        variable es_rojo : boolean;
        variable color_pos : integer range 0 to 23;
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

            when x"4" => -- RULETA CASINO - Franjas horizontales de colores
                for col in 0 to 7 loop
                    -- Calcular la posición del color con el offset de animación
                    color_pos := (col + ruleta_offset) mod 24;
                    
                    -- Dividir en 3 franjas de 8 posiciones cada una
                    if color_pos < 8 then
                        -- Franja VERDE
                        r(col) <= '1';
                        g(col) <= '0';
                        b(col) <= '1';
                    elsif color_pos < 16 then
                        -- Franja ROJA
                        r(col) <= '0';
                        g(col) <= '1';
                        b(col) <= '1';
                    else
                        -- Franja AZUL
                        r(col) <= '1';
                        g(col) <= '1';
                        b(col) <= '0';
                    end if;
                end loop;

            when x"6" => -- ANIMACIÓN DE VICTORIA - Parpadeo multicolor
                if victoria_parpadeo = '1' then
                    -- Alternar entre verde brillante y amarillo (verde + rojo)
                    if numero_fila mod 2 = 0 then
                        -- Verde
                        r <= (others => '1');
                        g <= (others => '0');
                        b <= (others => '1');
                    else
                        -- Amarillo (verde + rojo)
                        r <= (others => '0');
                        g <= (others => '0');
                        b <= (others => '1');
                    end if;
                else
                    -- Apagado durante el parpadeo
                    r <= (others => '1');
                    g <= (others => '1');
                    b <= (others => '1');
                end if;

            when x"7" => -- ANIMACIÓN DE DERROTA - X Roja
                for col in 0 to 7 loop
                    if datos_fila_actual(col) = '1' then
                        -- X en ROJO
                        r(col) <= '0';
                        g(col) <= '1'; 
                        b(col) <= '1'; 
                    else
                        -- Fondo apagado
                        r(col) <= '1';
                        g(col) <= '1';
                        b(col) <= '1';
                    end if;
                end loop;

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

            when others => -- Menú
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