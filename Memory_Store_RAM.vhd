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
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13"; -- Necesario para limpiar Y

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  constant ROM_CODE : t_mem_array := (
    -- ============================================================
    -- 1. INICIO (Dir 0)
    -- ============================================================
    0 => OP_WAIT, 1 => x"00", 2 => x"00",
    3 => OP_LDI, 4 => x"32", 5 => x"00",      
    6 => OP_STX, 7 => x"80", 8 => x"00",      

    -- MENU (Dir 9)
    9 => OP_LDX, 10 => x"80", 11 => x"00",
    12 => OP_DISP, 13 => x"00", 14 => x"00",
    15 => OP_LDI, 16 => x"10", 17 => x"00",
    18 => OP_STX, 19 => x"D0", 20 => x"00", 

    -- ESPERAR TECLA (Dir 21)
    21 => OP_LDX, 22 => x"F0", 23 => x"00", 
    -- Para comparar con 0, primero limpiamos Y
    24 => OP_LDIY, 25 => x"00", 26 => x"00", 
    27 => OP_CMP, 28 => x"00", 29 => x"00",
    30 => OP_BR_NZ, 31 => x"24", 32 => x"00", -- Si hay tecla, ir a JUEGO (Dir 36 = x24)
    33 => OP_JUMP, 34 => x"15", 35 => x"00",  -- Loop (Dir 21 / x15)

    -- JUEGO (Dir 36 / x24)
    36 => OP_STX, 37 => x"82", 38 => x"00", -- Guardar Apuesta
    39 => OP_DISP, 40 => x"00", 41 => x"00",
    42 => OP_LDI, 43 => x"20", 44 => x"00",
    45 => OP_STX, 46 => x"D0", 47 => x"00",
    48 => OP_WAIT, 49 => x"00", 50 => x"00", 
    51 => OP_WAIT, 52 => x"00", 53 => x"00",
    
    -- RESULTADO
    54 => OP_LDX, 55 => x"E1", 56 => x"00", 
    57 => OP_DISP, 58 => x"00", 59 => x"00", 
    60 => OP_STX, 61 => x"83", 62 => x"00", 
    
    -- COMPARAR
    63 => OP_LDY, 64 => x"82", 65 => x"00", -- Y = Apuesta
    66 => OP_CMP, 67 => x"00", 68 => x"00", 
    69 => OP_BR_NZ, 70 => x"54", 71 => x"00", -- Si pierde ir a 84 (x54)

    -- GANASTE (Dir 72)
    72 => OP_LDI, 73 => x"40", 74 => x"00", 
    75 => OP_STX, 76 => x"D0", 77 => x"00",
    78 => OP_LDI, 79 => x"99", 80 => x"00", 
    81 => OP_JUMP, 82 => x"5D", 83 => x"00", -- Ir a FIN (Dir 93 / x5D)

    -- PERDISTE (Dir 84 / x54)
    84 => OP_LDI, 85 => x"50", 86 => x"00", 
    87 => OP_STX, 88 => x"D0", 89 => x"00",
    90 => OP_LDI, 91 => x"0A", 92 => x"00", 

    -- FIN Y ACTUALIZAR (Dir 93 / x5D)
    93 => OP_STX, 94 => x"80", 95 => x"00",
    96 => OP_WAIT, 97 => x"00", 98 => x"00", 

    -- ============================================================
    -- FASE DE ENFRIAMIENTO CORREGIDA (Dir 99)
    -- ============================================================
    -- 1. LIMPIAR Y (Para que la comparación sea contra 0)
    99 => OP_LDIY, 100 => x"00", 101 => x"00", -- Y <= 0

    -- 2. LEER TECLADO
    102 => OP_LDX, 103 => x"F0", 104 => x"00", -- X <= Teclado

    -- 3. COMPARAR (X vs Y) -> (Teclado vs 0)
    105 => OP_CMP, 106 => x"00", 107 => x"00",

    -- 4. SI NO ES 0 (Sigue presionado), REPETIR DESDE 102
    108 => OP_BR_NZ, 109 => x"66", 110 => x"00", -- Saltar a 102 (x66)
    
    -- 5. SI ES 0 (Soltó), VOLVER AL MENU
    111 => OP_JUMP, 112 => x"09", 113 => x"00", -- Ir a Dir 9

    others => x"00"
  );

  signal RAM_DATA : t_mem_array := (others => x"00");

begin
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

    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;
end architecture;