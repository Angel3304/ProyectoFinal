library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_matriz_ruleta is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- PUERTO DE CONTROL (Viene de la CPU Address xD0)
        video_cmd   : in  STD_LOGIC_VECTOR(7 downto 0);
        
        -- Entradas de Datos para visualizar (Vienen de variables del sistema si es necesario)
        puntos_in   : in  STD_LOGIC_VECTOR(7 downto 0); -- Para mostrar en TUxx
        
        -- Salidas físicas a la Matriz
        row_out     : out STD_LOGIC_VECTOR(7 downto 0);
        r_out       : out STD_LOGIC_VECTOR(7 downto 0);
        g_out       : out STD_LOGIC_VECTOR(7 downto 0);
        b_out       : out STD_LOGIC_VECTOR(7 downto 0)
    );
end control_matriz_ruleta;

architecture Behavioral of control_matriz_ruleta is
    -- Señales para multiplexación
    signal fila_actual : integer range 0 to 7 := 0;
    signal contador_mux : integer := 0;
    
    -- Decodificación del comando
    signal comando_tipo : std_logic_vector(3 downto 0); -- Nibble alto (Ej: x4)
    signal comando_dato : integer range 0 to 15;        -- Nibble bajo (Ej: x0)

    -- Colores temporales
    signal r_temp, g_temp, b_temp : std_logic_vector(7 downto 0);

begin

    comando_tipo <= video_cmd(7 downto 4);
    comando_dato <= to_integer(unsigned(video_cmd(3 downto 0)));

    -- =========================================================
    -- PROCESO 1: Multiplexación de Filas (Barrido constante)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if contador_mux < 5000 then -- Ajustar velocidad de barrido
                contador_mux <= contador_mux + 1;
            else
                contador_mux <= 0;
                if fila_actual = 7 then
                    fila_actual <= 0;
                else
                    fila_actual <= fila_actual + 1;
                end if;
            end if;
        end if;
    end process;

    -- Activar fila física (Active Low o High según tu hardware, asumo Common Cathode/Anode)
    -- Basado en tu PDF, parece que activas 1 fila a la vez.
    process(fila_actual)
    begin
        row_out <= (others => '0');
        row_out(fila_actual) <= '1'; 
    end process;

    -- =========================================================
    -- PROCESO 2: Lógica de Pintado (Combinacional)
    -- =========================================================
    process(fila_actual, comando_tipo, comando_dato, puntos_in)
    begin
        -- Reset visual (Apagar todo por defecto - lógica negativa o positiva según display)
        r_temp <= (others => '1'); 
        g_temp <= (others => '1'); 
        b_temp <= (others => '1');

        case comando_tipo is
            
            -- x"10": PANTALLA IDLE (TU + Puntos)
            when x"1" => 
                -- Aquí implementas la lógica de "TU" en filas 0-2
                -- Y usas 'puntos_in' para mostrar los dígitos en filas 3-7
                -- (Reutiliza tu lógica de 'memoria_digitos_5x3' aquí)
                if fila_actual < 3 then
                    r_temp <= "01011110"; -- Ejemplo patrón hardcodeado
                end if;

            -- x"20": SELECCION DE COLOR
            when x"2" =>
                -- Mostrar cuadrados Rojo, Azul, Verde para que el usuario elija
                if fila_actual = 0 then r_temp <= x"00"; end if; -- Barra Roja
                if fila_actual = 1 then b_temp <= x"00"; end if; -- Barra Azul
                if fila_actual = 2 then g_temp <= x"00"; end if; -- Barra Verde

            -- x"40": ANIMACIÓN GIRO
            when x"4" =>
                -- Patrón psicodélico o rotatorio simple
                r_temp(fila_actual) <= '0';
                g_temp((fila_actual + 1) mod 8) <= '0';

            -- x"50": RESULTADO
            when x"5" =>
                -- 'comando_dato' tiene el número (0-9).
                -- 1. Buscas el patrón del número en tu 'memoria_patrones' (no incluida aquí por espacio)
                -- 2. Determinas el color de fondo:
                --    Si comando_dato es par (Rojo), impar (Azul), 0 (Verde).
                
                -- Lógica simplificada de color de fondo:
                if comando_dato = 0 then -- Verde
                     g_temp <= (others => '0'); 
                elsif (comando_dato mod 2) = 0 then -- Rojo
                     r_temp <= (others => '0');
                else -- Azul
                     b_temp <= (others => '0');
                end if;
                
                -- Nota: Aquí deberías superponer el número en Blanco (OFF) sobre el fondo.

            when others =>
                null; -- Pantalla en negro
        end case;
    end process;

    -- Asignación a salida
    r_out <= r_temp;
    g_out <= g_temp;
    b_out <= b_temp;

end Behavioral;