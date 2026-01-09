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
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; 

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  constant ROM_CODE : t_mem_array := (
    -- ============================================================
    -- 1. INICIO (Dir 0)
    -- ============================================================
    -- Aseguramos Saldo en RAM (aunque ya lo vemos por hardware)
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => x"80", 5 => x"00",      

    -- Resetear Pantalla (A Roja)
    6 => OP_LDI, 7 => x"10", 8 => x"00",
    9 => OP_STX, 10 => x"D0", 11 => x"00", 

    -- ============================================================
    -- 2. ESPERAR A SOLTAR (SILENCIOSO) - Dir 12
    -- ============================================================
    -- Aquí arreglamos el error del "14".
    -- Leemos teclado. Si hay algo presionado (!= 0), repetimos aquí mismo.
    -- No mostramos error, solo esperamos.
    12 => OP_LDX, 13 => x"F0", 14 => x"00", 
    15 => OP_CMP, 16 => x"00", 17 => x"00", 
    18 => OP_BR_NZ, 19 => x"0C", 20 => x"00", -- Si tecla != 0, volver a 12 (x0C)

    -- ============================================================
    -- 3. ESPERAR JUGADA (Dir 21)
    -- ============================================================
    -- Aquí el teclado ya está libre (0). Esperamos que presiones.
    
    -- Restauramos el 50 en pantalla (por si acaso)
    21 => OP_LDX, 22 => x"80", 23 => x"00",
    24 => OP_DISP, 25 => x"00", 26 => x"00",

    -- Bucle de lectura
    27 => OP_LDX, 28 => x"F0", 29 => x"00", 
    30 => OP_CMP, 31 => x"00", 32 => x"00",
    
    -- Si detecta tecla, IR A JUEGO (Dir 39 = x27)
    33 => OP_BR_NZ, 34 => x"27", 35 => x"00",
    
    -- Si es 0, seguir esperando (Dir 27 = x1B)
    36 => OP_JUMP, 37 => x"1B", 38 => x"00",

    -- ============================================================
    -- 4. JUEGO (Dir 39 / x27)
    -- ============================================================
    -- Guardar Apuesta en RAM[x82]
    39 => OP_STX, 40 => x"82", 41 => x"00",
    42 => OP_DISP, 43 => x"00", 44 => x"00", -- Mostrar tecla pulsada
    
    -- ANIMACIÓN (Barras)
    45 => OP_LDI, 46 => x"20", 47 => x"00",
    48 => OP_STX, 49 => x"D0", 50 => x"00",
    
    -- TIEMPO DE GIRO
    51 => OP_WAIT, 52 => x"00", 53 => x"00", 
    54 => OP_WAIT, 55 => x"00", 56 => x"00",

    -- RESULTADO (Random)
    57 => OP_LDX, 58 => x"E1", 59 => x"00", 
    60 => OP_DISP, 61 => x"00", 62 => x"00", -- Mostrar Resultado
    63 => OP_STX, 64 => x"83", 65 => x"00", 

    -- COMPARAR
    66 => OP_LDY, 67 => x"82", 68 => x"00", -- Y = Apuesta
    69 => OP_CMP, 70 => x"00", 71 => x"00", 
    72 => OP_BR_NZ, 73 => x"54", 74 => x"00", -- Si diferente, ir a PERDER (Dir 84 = x54)

    -- GANASTE (Dir 75)
    75 => OP_LDI, 76 => x"40", 77 => x"00", 
    78 => OP_STX, 79 => x"D0", 80 => x"00",
    81 => OP_LDI, 82 => x"99", 83 => x"00", -- Saldo 99
    84 => OP_JUMP, 85 => x"5A", 86 => x"00", -- Ir a FIN (Dir 90 = x5A)

    -- PERDISTE (Dir 87 / x57 - Ajustado)
    87 => OP_LDI, 88 => x"50", 89 => x"00", 
    90 => OP_STX, 91 => x"D0", 92 => x"00",
    93 => OP_LDI, 94 => x"0A", 95 => x"00", -- Saldo 10

    -- FIN Y ACTUALIZAR (Dir 96 / x60)
    96 => OP_STX, 97 => x"80", 98 => x"00", -- Guardar nuevo saldo
    99 => OP_WAIT, 100 => x"00", 101 => x"00", -- Ver resultado
    
    -- VOLVER AL "ESPERAR SOLTAR" (Dir 12)
    -- Esto evita el rebote infinito.
    102 => OP_JUMP, 103 => x"0C", 104 => x"00", 

    others => x"00"
  );

  signal RAM_DATA : t_mem_array := (others => x"00");

begin
    -- LECTURA (ROM + RAM)
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
        variable b0, b1, b2 : std_logic_vector(7 downto 0);
    begin
        addr_int := to_integer(unsigned(Addr_in));
        b0 := ROM_CODE(addr_int)     or RAM_DATA(addr_int);
        b1 := ROM_CODE(addr_int + 1) or RAM_DATA(addr_int + 1);
        b2 := ROM_CODE(addr_int + 2) or RAM_DATA(addr_int + 2);
        Data_out <= b0 & b1 & b2;
    end process;

    -- ESCRITURA
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;
end architecture;