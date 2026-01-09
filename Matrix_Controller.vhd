library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Matrix_Controller is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic; 
        
        -- CAMBIO: Ahora recibe 'video_cmd' desde la CPU (Address x"D0")
        video_cmd : in  std_logic_vector(7 downto 0); 
        
        -- Salidas a la protoboard
        row       : out std_logic_vector(7 downto 0); 
        r         : out std_logic_vector(0 to 7); 
        g         : out std_logic_vector(0 to 7); 
        b         : out std_logic_vector(0 to 7)
    );
end Matrix_Controller;

architecture Behavioral of Matrix_Controller is

    signal contador_reloj : integer range 0 to 50000 := 0;
    signal numero_fila    : integer range 0 to 7 := 0;

    -- Decodificación del comando CPU
    signal cmd_type : std_logic_vector(3 downto 0); -- Nibble alto (Ej: x5)
    signal cmd_data : integer range 0 to 15;        -- Nibble bajo (Ej: x7)

    type digit_pattern_t is array (0 to 7) of std_logic_vector(7 downto 0);
    signal datos_fila_actual : std_logic_vector(7 downto 0);
    signal patron_seleccionado : digit_pattern_t;
    
    -- Señales para animación de giro
    signal giro_offset : integer range 0 to 7 := 0;
    signal count_anim  : integer range 0 to 5000000 := 0;

    -- =========================================================
    -- BANCO DE IMÁGENES (Tus números originales)
    -- =========================================================
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
            
            -- x"A" (10): Letra 'A' (Rojo)
            when 10 => return ("00011000", "00111100", "01100110", "01100110", "01111110", "01100110", "01100110", "00000000");
            -- x"B" (11): Letra 'b' (Azul)
            when 11 => return ("01000000", "01000000", "01000000", "01111100", "01100110", "01100110", "01111100", "00000000");
            -- x"C" (12): Letra 'C' (Verde)
            when 12 => return ("00111100", "01100110", "01100000", "01100000", "01100000", "01100110", "00111100", "00000000");

            when others => return ("10000001", "01000010", "00100100", "00011000", "00011000", "00100100", "01000010", "10000001");
        end case;
    end function;

begin
    
    -- Separar comando y dato
    cmd_type <= video_cmd(7 downto 4);
    cmd_data <= to_integer(unsigned(video_cmd(3 downto 0)));

    -- 1. SELECCIÓN DE PATRÓN SEGÚN COMANDO
    process(cmd_type, cmd_data, giro_offset)
    begin
        case cmd_type is
            when x"1" => -- MENU (Muestra 'A' como ejemplo o TU)
                 patron_seleccionado <= get_pattern(10); 
            when x"5" => -- RESULTADO (Muestra el número ganado)
                 patron_seleccionado <= get_pattern(cmd_data);
            when x"4" => -- GIRO (Patrón dinámico)
                 -- Crea una línea que se mueve
                 for i in 0 to 7 loop
                    if i = giro_offset then 
                        patron_seleccionado(i) <= "11111111"; 
                    else 
                        patron_seleccionado(i) <= "00000000"; 
                    end if;
                 end loop;
            when others => -- Selección de color, etc. (No usa patrón de bits, usa color directo)
                 patron_seleccionado <= (others => (others => '0'));
        end case;
    end process;

    -- 2. DIVISOR DE FRECUENCIA PARA BARRIDO Y ANIMACION
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
            
            -- Animación de Giro (Solo si cmd es x40)
            if cmd_type = x"4" then
                if count_anim = 1000000 then -- Velocidad visual del giro
                    count_anim <= 0;
                    if giro_offset = 7 then giro_offset <= 0; else giro_offset <= giro_offset + 1; end if;
                else
                    count_anim <= count_anim + 1;
                end if;
            end if;
        end if;
    end process;

    -- 3. ACTIVAR FILA FÍSICA
    process(numero_fila)
    begin
        row <= (others => '0');
        row(numero_fila) <= '1'; 
    end process;

    -- 4. LOGICA DE COLOR Y PIXELES
    datos_fila_actual <= patron_seleccionado(numero_fila);

    process(numero_fila, cmd_type, cmd_data, datos_fila_actual)
        variable num_int : integer;
        variable es_rojo : boolean;
    begin
        -- Reset de color (APAGADO = '1' en cátodo común invertido o según tu hardware)
        -- Asumiendo tu hardware: '1' apaga, '0' enciende (como en tu código original)
        r <= (others => '1'); g <= (others => '1'); b <= (others => '1');

        case cmd_type is
            -- ======================================================
            -- ESTADO: SELECCIÓN DE COLOR (Muestra 3 barras)
            -- ======================================================
            when x"2" =>
                if numero_fila < 2 then      -- Arriba: ROJO
                    r <= x"00"; -- Enciende toda la fila en Rojo
                elsif numero_fila < 5 then   -- Medio: AZUL
                    b <= x"00";
                else                         -- Abajo: VERDE
                    g <= x"00";
                end if;

            -- ======================================================
            -- ESTADO: RESULTADO (Muestra Número + Color de Fondo)
            -- ======================================================
            when x"5" =>
                -- Tu lógica original de paridad para el fondo
                num_int := cmd_data;
                
                -- Detectar Rojo (Simplificado pares/impares para 0-9)
                -- 1,3,5,7,9 son Impares (ROJO en tu código original decías impares=azul? Ajusto a ruleta real o tu lógica)
                -- Tu código original: 2,4,6,8 -> Rojo. 1,3,5,7,9 -> Azul.
                if (num_int = 2 or num_int = 4 or num_int = 6 or num_int = 8) then
                    es_rojo := true;
                else
                    es_rojo := false;
                end if;

                for col in 0 to 7 loop
                    if datos_fila_actual(col) = '1' then
                        -- El número siempre en BLANCO o AMARILLO para que resalte
                        r(col) <= '0'; g(col) <= '0'; b(col) <= '0'; -- Blanco
                    else
                        -- Fondo
                        if num_int = 0 then       -- Cero = Verde
                            g(col) <= '0';
                        elsif es_rojo then        -- Rojo
                            r(col) <= '0';
                        else                      -- Azul (Negro)
                            b(col) <= '0';
                        end if;
                    end if;
                end loop;

            -- ======================================================
            -- ESTADO: MENÚ y GIRO (Dibujo simple)
            -- ======================================================
            when others =>
                -- Simplemente dibuja los bits del patrón en BLANCO
                for col in 0 to 7 loop
                    if datos_fila_actual(col) = '1' then
                        r(col) <= '0'; g(col) <= '0'; b(col) <= '0';
                    end if;
                end loop;
        end case;
    end process;

end Behavioral;