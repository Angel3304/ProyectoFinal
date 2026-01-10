library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memory_Store_RAM is
    port(
        clk, we  : in std_logic;
        Addr_in  : in std_logic_vector(7 downto 0);
        Data_in  : in std_logic_vector(23 downto 0); 
        Data_out : out std_logic_vector(23 downto 0) 
    );
end entity Memory_Store_RAM;

architecture Behavioral of Memory_Store_RAM is

  -- OPCODES
  constant OP_LDX   : std_logic_vector(7 downto 0) := x"01";
  constant OP_LDY   : std_logic_vector(7 downto 0) := x"02";
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05"; -- Resta X - Y (Afecta flags)
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08"; -- Salta si NO es igual
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; 
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  constant ROM_CODE : t_mem_array := (
    -- ============================================================
    -- 1. INICIALIZACIÓN
    -- ============================================================
    -- Cargar 50 en Saldo [x80]
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => x"80", 5 => x"00",      

    -- ============================================================
    -- 2. MENÚ Y SELECCIÓN (Bucle Principal)
    -- ============================================================
    -- Etiqueta: MENU_LOOP (Dir 6)
    -- Mostrar Saldo Actual
    6 => OP_LDX, 7 => x"80", 8 => x"00",      
    9 => OP_DISP, 10 => x"00", 11 => x"00",   
    
    -- Resetear Video (A Roja)
    12 => OP_LDI, 13 => x"10", 14 => x"00",
    15 => OP_STX, 16 => x"D0", 17 => x"00", 

    -- Etiqueta: LEER_TECLA (Dir 18)
    18 => OP_LDX, 19 => x"F0", 20 => x"00", -- Leer Teclado -> X
    
    -- Checar si es 0 (Nadie presiona)
    21 => OP_LDIY, 22 => x"00", 23 => x"00", 
    24 => OP_CMP, 25 => x"00", 26 => x"00",
    27 => OP_BR_NZ, 28 => x"24", 29 => x"00", -- Si tecla != 0, ir a PROCESAR (Dir 36 = x24)
    30 => OP_JUMP, 31 => x"12", 32 => x"00",  -- Si es 0, Loop a LEER_TECLA (Dir 18 = x12)

    -- Etiqueta: PROCESAR_TECLA (Dir 36 / x24)
    -- ¿Es la tecla '#' (Start)? '#' suele ser x"F" en tu scanner
    36 => OP_LDIY, 37 => x"0F", 38 => x"00", -- Y = 15 (#)
    39 => OP_CMP, 40 => x"00", 41 => x"00",  -- X - Y
    
    -- Si NO es # (es decir, es un número), saltar a GUARDAR_APUESTA
    42 => OP_BR_NZ, 43 => x"33", 44 => x"00", -- Ir a Dir 51 (x33)

    -- SI ES '#' -> JUMP TO SPIN (Continuar aquí abajo)
    45 => OP_JUMP, 46 => x"3F", 47 => x"00",  -- Ir a SPIN (Dir 63 = x3F)

    -- Etiqueta: GUARDAR_APUESTA (Dir 51 / x33)
    -- Si llegamos aquí, presionaste un número (apuesta).
    51 => OP_STX, 52 => x"82", 53 => x"00", -- Guardar en Selección [x82]
    54 => OP_DISP, 55 => x"00", 56 => x"00", -- Mostrar número en display
    
    -- Esperar a que sueltes la tecla para no parpadear
    57 => OP_WAIT, 58 => x"00", 59 => x"00", -- Pequeña pausa
    60 => OP_JUMP, 61 => x"12", 62 => x"00", -- Volver a LEER_TECLA (Dir 18) para esperar el '#'

    -- ============================================================
    -- 3. ANIMACIÓN Y JUEGO (Dir 63 / x3F)
    -- ============================================================
    -- Matriz Colores (Giro)
    63 => OP_LDI, 64 => x"20", 65 => x"00",
    66 => OP_STX, 67 => x"D0", 68 => x"00",
    
    -- Tiempo de Giro
    69 => OP_WAIT, 70 => x"00", 71 => x"00", 
    72 => OP_WAIT, 73 => x"00", 74 => x"00",

    -- Resultado Random
    75 => OP_LDX, 76 => x"E1", 77 => x"00", 
    78 => OP_DISP, 79 => x"00", 80 => x"00", -- Mostrar Random
    81 => OP_STX, 82 => x"83", 83 => x"00", 
    
    -- Verificar Ganador
    84 => OP_LDY, 85 => x"82", 86 => x"00", -- Cargar Apuesta Guardada
    87 => OP_CMP, 88 => x"00", 89 => x"00", 
    90 => OP_BR_NZ, 91 => x"69", 92 => x"00", -- Si diferente, PERDER (Dir 105 = x69)

    -- GANASTE (Dir 93)
    93 => OP_LDI, 94 => x"40", 95 => x"00", -- Verde
    96 => OP_STX, 97 => x"D0", 98 => x"00",
    99 => OP_LDI, 100 => x"99", 101 => x"00", -- Saldo 99
    102 => OP_JUMP, 103 => x"72", 104 => x"00", -- Ir a FIN (Dir 114 = x72)

    -- PERDISTE (Dir 105 / x69)
    105 => OP_LDI, 106 => x"50", 107 => x"00", -- Rojo
    108 => OP_STX, 109 => x"D0", 110 => x"00",
    111 => OP_LDI, 112 => x"0A", 113 => x"00", -- Saldo 10

    -- FIN (Dir 114 / x72)
    114 => OP_STX, 115 => x"80", 116 => x"00", -- Guardar Nuevo Saldo
    117 => OP_WAIT, 118 => x"00", 119 => x"00", -- Ver resultado

    -- ENFRIAMIENTO (Esperar a soltar '#')
    120 => OP_LDX, 121 => x"F0", 122 => x"00",
    123 => OP_LDIY, 124 => x"00", 125 => x"00",
    126 => OP_CMP, 127 => x"00", 128 => x"00",
    129 => OP_BR_NZ, 130 => x"78", 131 => x"00", -- Si sigue presionado, loop (x78 = 120)
    
    -- VOLVER
    132 => OP_JUMP, 133 => x"06", 134 => x"00", -- Ir a MENU (Dir 6)

    others => x"00"
  );

  -- RAM: DATOS 
  signal RAM_DATA : t_mem_array := (others => x"00");

begin

    -- Lógica Split ROM/RAM
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(Addr_in));
        if addr_int < 128 then
            Data_out <= ROM_CODE(addr_int) & ROM_CODE(addr_int + 1) & ROM_CODE(addr_int + 2);
        else
            Data_out <= RAM_DATA(addr_int) & RAM_DATA(addr_int + 1) & RAM_DATA(addr_int + 2);
        end if;
    end process;

    -- Escritura
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' and to_integer(unsigned(Addr_in)) >= 128 then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;

end architecture;