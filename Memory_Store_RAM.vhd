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
  constant OP_ADD   : std_logic_vector(7 downto 0) := x"03";
  -- OP_SUB utiliza el código 09 que está soportado en la ALU (Restar y guardar en X)
  constant OP_SUB   : std_logic_vector(7 downto 0) := x"09"; 
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08"; 
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_DIV   : std_logic_vector(7 downto 0) := x"10"; 
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; 
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  -- MAPA DE MEMORIA
  constant R_SALDO     : std_logic_vector(7 downto 0) := x"B0"; -- 176
  constant W_SALDO     : std_logic_vector(7 downto 0) := x"B2"; -- 178
  constant R_APUESTA   : std_logic_vector(7 downto 0) := x"B3";
  constant W_APUESTA   : std_logic_vector(7 downto 0) := x"B5";
  constant R_RESULTADO : std_logic_vector(7 downto 0) := x"B6";
  constant W_RESULTADO : std_logic_vector(7 downto 0) := x"B8";

  constant ROM_CODE : t_mem_array := (
    -- 1. INICIALIZACIÓN (Dir 0)
    -- =========================================================
    0 => OP_LDI, 1 => x"32", 2 => x"00",      -- Saldo inicial = 50 (x32)
    3 => OP_STX, 4 => W_SALDO, 5 => x"00",      
    
    6 => OP_LDI, 7 => x"10", 8 => x"00",
    9 => OP_STX, 10 => x"D0", 11 => x"00", 

    -- 2. BARRERA DE SEGURIDAD (Dir 12)
    -- =========================================================
    12 => OP_LDIY, 13 => x"00", 14 => x"00", 
    15 => OP_LDX, 16 => x"F0", 17 => x"00", 
    18 => OP_CMP, 19 => x"00", 20 => x"00", 
    21 => OP_BR_NZ, 22 => x"0C", 23 => x"00", 

    -- 3. MENÚ PRINCIPAL (Dir 24)
    -- =========================================================
    24 => OP_LDX, 25 => R_SALDO, 26 => x"00",      
    27 => OP_DISP, 28 => x"00", 29 => x"00",   

    -- LEER INPUT (Dir 30)
    30 => OP_LDX, 31 => x"F0", 32 => x"00", 
    33 => OP_LDIY, 34 => x"00", 35 => x"00", 
    36 => OP_CMP, 37 => x"00", 38 => x"00",
    39 => OP_BR_NZ, 40 => x"2D", 41 => x"00", 
    42 => OP_JUMP, 43 => x"1E", 44 => x"00",  

    -- PROCESAR TECLA (Dir 45 / x2D)
    45 => OP_LDIY, 46 => x"0F", 47 => x"00", 
    48 => OP_CMP, 49 => x"00", 50 => x"00",  
    51 => OP_BR_NZ, 52 => x"39", 53 => x"00", 
    54 => OP_JUMP, 55 => x"45", 56 => x"00",  

    -- GUARDAR APUESTA (Dir 57 / x39)
    57 => OP_STX, 58 => W_APUESTA, 59 => x"00", 
    60 => OP_DISP, 61 => x"00", 62 => x"00", 
    63 => OP_WAIT, 64 => x"00", 65 => x"00", 
    66 => OP_JUMP, 67 => x"1E", 68 => x"00", 

    -- 4. JUEGO Y GIRO (Dir 69 / x45)
    -- =========================================================
    69 => OP_LDI, 70 => x"40", 71 => x"00", 
    72 => OP_STX, 73 => x"D0", 74 => x"00",
    
    75 => OP_WAIT, 76 => x"00", 77 => x"00", 
    78 => OP_WAIT, 79 => x"00", 80 => x"00",

    -- =========================================================
    -- GENERACIÓN DE RESULTADO CON DIVISIÓN HW (Dir 81)
    -- =========================================================
    81 => OP_LDX, 82 => x"E1", 83 => x"00", 
    
    -- Divisor 38 (x26)
    84 => OP_LDIY, 85 => x"26", 86 => x"00", 
    
    -- DIVIDIR (X / Y). Residuo en Y.
    87 => OP_DIV, 88 => x"00", 89 => x"00", 
    
    -- X = 0 + Y (Mover residuo a X)
    90 => OP_LDI, 91 => x"00", 92 => x"00", 
    93 => OP_ADD, 94 => x"00", 95 => x"00", 
    
    -- 5. Mostrar y Guardar
    96 => OP_DISP, 97 => x"00", 98 => x"00", 
    99 => OP_STX, 100 => W_RESULTADO, 101 => x"00", 
    
    -- Comparar con Apuesta
    102 => OP_LDY, 103 => R_APUESTA, 104 => x"00", 
    105 => OP_CMP, 106 => x"00", 107 => x"00", 
    108 => OP_BR_NZ, 109 => x"7B", 110 => x"00", -- Ir a PERDER (Dir 123)

    -- GANASTE (Dir 111)
    -- (Opcional: aquí podrías sumar también, por ahora lo dejamos fijo o como estaba)
    111 => OP_LDI, 112 => x"60", 113 => x"00", 
    114 => OP_STX, 115 => x"D0", 116 => x"00",
    117 => OP_LDI, 118 => x"99", 119 => x"00", -- Saldo gana 99
    120 => OP_JUMP, 121 => x"84", 122 => x"00", -- Ir a FIN (Dir 132)

    -- PERDISTE (Dir 123 / x7B) - MODIFICADO
    -- =========================================================
    123 => OP_LDI, 124 => x"70", 125 => x"00", -- Cargar Animación Derrota
    126 => OP_STX, 127 => x"D0", 128 => x"00", -- Enviar a Video
    -- En vez de cargar 10 fijo, saltamos a la lógica de resta (Dir 153 / x99)
    129 => OP_JUMP, 130 => x"99", 131 => x"00", 

    -- FIN (Dir 132 / x84)
    -- Aquí llegamos con el nuevo saldo en X
    132 => OP_STX, 133 => W_SALDO, 134 => x"00", 
    135 => OP_WAIT, 136 => x"00", 137 => x"00", 

    -- ENFRIAMIENTO (Dir 138)
    138 => OP_LDIY, 139 => x"00", 140 => x"00",
    141 => OP_LDX, 142 => x"F0", 143 => x"00",
    144 => OP_CMP, 145 => x"00", 146 => x"00",
    147 => OP_BR_NZ, 148 => x"8A", 149 => x"00", 
    
    -- VOLVER A MENU (Dir 150)
    150 => OP_JUMP, 151 => x"18", 152 => x"00", 

    -- =========================================================
    -- LÓGICA EXTENDIDA: RESTAR 5 AL SALDO (Dir 153 / x99)
    -- =========================================================
    153 => OP_LDX,  154 => R_SALDO, 155 => x"00", -- Cargar Saldo actual en X
    156 => OP_LDIY, 157 => x"05",    158 => x"00", -- Cargar 5 en Y (Apuesta Fija)
    159 => OP_SUB,  160 => x"00",    161 => x"00", -- X = X - Y (Saldo - 5)
    162 => OP_JUMP, 163 => x"84",    164 => x"00", -- Volver a FIN (Dir 132) para guardar

    others => x"00"
  );

  signal RAM_DATA : t_mem_array := (others => x"00");

begin
    -- Memoria Split
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(Addr_in));
        if addr_int < 170 then
            Data_out <= ROM_CODE(addr_int) & ROM_CODE(addr_int + 1) & ROM_CODE(addr_int + 2);
        else
            Data_out <= RAM_DATA(addr_int) & RAM_DATA(addr_int + 1) & RAM_DATA(addr_int + 2);
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' and to_integer(unsigned(Addr_in)) >= 170 then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;

end architecture;