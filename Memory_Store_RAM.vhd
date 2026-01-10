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
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  constant ROM_CODE : t_mem_array := (
    -- ============================================================
    -- 1. INICIO INSTANTÁNEO (Dir 0)
    -- ============================================================
    -- Eliminamos los OP_WAIT. Arrancamos directo configurando saldo.
    0 => OP_LDI, 1 => x"32", 2 => x"00",      -- Cargar 50 en X
    3 => OP_STX, 4 => x"80", 5 => x"00",      -- Guardar en RAM[x80]
    
    -- Forzamos mostrar el saldo y resetear video inmediatamente
    6 => OP_DISP, 7 => x"00", 8 => x"00",     
    9 => OP_LDI, 10 => x"10", 11 => x"00",
    12 => OP_STX, 13 => x"D0", 14 => x"00", 

    -- ============================================================
    -- 2. BUCLE PRINCIPAL (Dir 15)
    -- ============================================================
    -- Aquí comienza la espera activa de la tecla.
    
    -- LEER TECLADO (Dir 15 / x0F)
    15 => OP_LDX, 16 => x"F0", 17 => x"00", 
    
    -- LIMPIAR Y (Comparar contra 0)
    18 => OP_LDIY, 19 => x"00", 20 => x"00", 
    
    -- COMPARAR
    21 => OP_CMP, 22 => x"00", 23 => x"00",
    
    -- SI HAY TECLA (!= 0), IR A JUEGO (Dir 30 = x1E)
    24 => OP_BR_NZ, 25 => x"1E", 26 => x"00", 
    
    -- SI ES 0, REPETIR BUCLE (Ir a 15 / x0F)
    27 => OP_JUMP, 28 => x"0F", 29 => x"00",  

    -- ============================================================
    -- 3. JUEGO (Dir 30 / x1E)
    -- ============================================================
    -- Guardar Apuesta
    30 => OP_STX, 31 => x"82", 32 => x"00", 
    33 => OP_DISP, 34 => x"00", 35 => x"00", -- Feedback visual inmediato

    -- ANIMACIÓN (Barras x20)
    36 => OP_LDI, 37 => x"20", 38 => x"00",
    39 => OP_STX, 40 => x"D0", 41 => x"00",
    
    -- TIEMPO DE GIRO (Aquí sí esperamos para dar emoción)
    42 => OP_WAIT, 43 => x"00", 44 => x"00", 
    45 => OP_WAIT, 46 => x"00", 47 => x"00",
    
    -- RESULTADO (Random)
    48 => OP_LDX, 49 => x"E1", 50 => x"00", 
    51 => OP_DISP, 52 => x"00", 53 => x"00", 
    54 => OP_STX, 55 => x"83", 56 => x"00", 
    
    -- COMPARAR RESULTADO
    57 => OP_LDY, 58 => x"82", 59 => x"00", 
    60 => OP_CMP, 61 => x"00", 62 => x"00", 
    63 => OP_BR_NZ, 64 => x"4E", 65 => x"00", -- Si pierde ir a 78 (x4E)

    -- GANASTE (Dir 66)
    66 => OP_LDI, 67 => x"40", 68 => x"00", 
    69 => OP_STX, 70 => x"D0", 71 => x"00",
    72 => OP_LDI, 73 => x"99", 74 => x"00", 
    75 => OP_JUMP, 76 => x"54", 77 => x"00", -- Ir a FIN (Dir 84 / x54)

    -- PERDISTE (Dir 78 / x4E)
    78 => OP_LDI, 79 => x"50", 80 => x"00", 
    81 => OP_STX, 82 => x"D0", 83 => x"00",
    84 => OP_LDI, 85 => x"0A", 86 => x"00", 

    -- FIN Y ACTUALIZAR (Dir 84 / x54)
    -- (Nota: la etiqueta de salto anterior apuntaba aquí, ajustamos flujo)
    -- Aquí converge Ganar/Perder.
    -- X ya tiene el nuevo saldo (99 o 10).
    
    -- 1. Guardar Saldo
    87 => OP_STX, 88 => x"80", 89 => x"00",
    
    -- 2. Pausa para ver si ganaste/perdiste
    90 => OP_WAIT, 91 => x"00", 92 => x"00", 

    -- ============================================================
    -- 4. FASE DE ENFRIAMIENTO (Dir 93)
    -- ============================================================
    -- Obligamos a soltar la tecla para evitar rebotes o bucles.
    
    -- Limpiar Y
    93 => OP_LDIY, 94 => x"00", 95 => x"00",

    -- Leer Teclado -> X
    96 => OP_LDX, 97 => x"F0", 98 => x"00",

    -- Comparar X vs 0
    99 => OP_CMP, 100 => x"00", 101 => x"00",

    -- SI NO ES 0 (Sigue presionado), REPETIR DESDE 93 (x5D)
    102 => OP_BR_NZ, 103 => x"5D", 104 => x"00", 
    
    -- SI ES 0 (Soltó), VOLVER AL MENU INICIAL (Dir 6)
    -- Volvemos a la Dir 6 para que refresque el saldo (DISP) y quede listo.
    105 => OP_JUMP, 106 => x"06", 107 => x"00", 

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