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

  -- =========================================================
  -- MAPA DE MEMORIA CORREGIDO (TRUCO DE ALINEACIÓN)
  -- =========================================================
  -- La CPU descarta el primer byte al leer (LDX). 
  -- Por eso, LEEMOS en una dirección (R_) pero ESCRIBIMOS (W_) 2 bytes adelante.
  
  -- Variable SALDO: Base xA0 (160)
  constant R_SALDO : std_logic_vector(7 downto 0) := x"A0"; -- Leemos aquí
  constant W_SALDO : std_logic_vector(7 downto 0) := x"A2"; -- Escribimos aquí (+2)

  -- Variable APUESTA: Base xA3 (163)
  constant R_APUESTA : std_logic_vector(7 downto 0) := x"A3";
  constant W_APUESTA : std_logic_vector(7 downto 0) := x"A5";

  -- Variable RESULTADO: Base xA6 (166)
  constant R_RESULTADO : std_logic_vector(7 downto 0) := x"A6";
  constant W_RESULTADO : std_logic_vector(7 downto 0) := x"A8";


  constant ROM_CODE : t_mem_array := (
    -- 1. INICIALIZACIÓN (Dir 0)
    -- =========================================================
    -- Cargar 50 en Saldo (Usamos dirección de ESCRITURA W_)
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => W_SALDO, 5 => x"00",      
    
    -- Configurar Matriz (A Roja)
    6 => OP_LDI, 7 => x"10", 8 => x"00",
    9 => OP_STX, 10 => x"D0", 11 => x"00", 

    -- 2. BARRERA DE SEGURIDAD (Dir 12)
    -- =========================================================
    -- Esperar a que teclado sea 0
    12 => OP_LDIY, 13 => x"00", 14 => x"00", 
    15 => OP_LDX, 16 => x"F0", 17 => x"00", 
    18 => OP_CMP, 19 => x"00", 20 => x"00", 
    21 => OP_BR_NZ, 22 => x"0C", 23 => x"00", -- Loop a 12

    -- 3. MENÚ PRINCIPAL (Dir 24)
    -- =========================================================
    -- Cargar Saldo (Usamos dirección de LECTURA R_)
    24 => OP_LDX, 25 => R_SALDO, 26 => x"00",      
    27 => OP_DISP, 28 => x"00", 29 => x"00",   

    -- LEER INPUT (Dir 30)
    30 => OP_LDX, 31 => x"F0", 32 => x"00", 
    33 => OP_LDIY, 34 => x"00", 35 => x"00", 
    36 => OP_CMP, 37 => x"00", 38 => x"00",
    39 => OP_BR_NZ, 40 => x"2D", 41 => x"00", -- Ir a PROCESAR (Dir 45)
    42 => OP_JUMP, 43 => x"1E", 44 => x"00",  -- Loop a LEER (Dir 30)

    -- PROCESAR TECLA (Dir 45 / x2D)
    -- Checar si es '#' (xF)
    45 => OP_LDIY, 46 => x"0F", 47 => x"00", 
    48 => OP_CMP, 49 => x"00", 50 => x"00",  
    51 => OP_BR_NZ, 52 => x"39", 53 => x"00", -- Ir a GUARDAR APUESTA (Dir 57)
    54 => OP_JUMP, 55 => x"45", 56 => x"00",  -- Ir a GIRAR (Dir 69)

    -- GUARDAR APUESTA (Dir 57 / x39)
    57 => OP_STX, 58 => W_APUESTA, 59 => x"00", 
    60 => OP_DISP, 61 => x"00", 62 => x"00", 
    63 => OP_WAIT, 64 => x"00", 65 => x"00", 
    66 => OP_JUMP, 67 => x"1E", 68 => x"00", -- Volver a LEER (Dir 30)

    -- 4. JUEGO Y GIRO (Dir 69 / x45)
    -- =========================================================
    69 => OP_LDI, 70 => x"20", 71 => x"00", 
    72 => OP_STX, 73 => x"D0", 74 => x"00",
    
    -- Tiempos de Giro
    75 => OP_WAIT, 76 => x"00", 77 => x"00", 
    78 => OP_WAIT, 79 => x"00", 80 => x"00",

    -- Resultado Random
    81 => OP_LDX, 82 => x"E1", 83 => x"00", 
    84 => OP_DISP, 85 => x"00", 86 => x"00", 
    87 => OP_STX, 88 => W_RESULTADO, 89 => x"00", 
    
    -- Comparar (Leemos Apuesta con R_)
    90 => OP_LDY, 91 => R_APUESTA, 92 => x"00", 
    93 => OP_CMP, 94 => x"00", 95 => x"00", 
    96 => OP_BR_NZ, 97 => x"6F", 98 => x"00", -- Ir a PERDER (Dir 111)

    -- GANASTE (Dir 99)
    99 => OP_LDI, 100 => x"40", 101 => x"00", 
    102 => OP_STX, 103 => x"D0", 104 => x"00",
    105 => OP_LDI, 106 => x"99", 107 => x"00", -- Saldo 99 (Prueba)
    108 => OP_JUMP, 109 => x"78", 110 => x"00", -- Ir a FIN (Dir 120)

    -- PERDISTE (Dir 111 / x6F)
    111 => OP_LDI, 112 => x"50", 113 => x"00", 
    114 => OP_STX, 115 => x"D0", 116 => x"00",
    117 => OP_LDI, 118 => x"0A", 119 => x"00", -- Saldo 10 (Prueba)

    -- FIN (Dir 120 / x78)
    -- Guardamos el nuevo saldo (W_)
    120 => OP_STX, 121 => W_SALDO, 122 => x"00", 
    123 => OP_WAIT, 124 => x"00", 125 => x"00", 

    -- ENFRIAMIENTO (Dir 126)
    126 => OP_LDIY, 127 => x"00", 128 => x"00",
    129 => OP_LDX, 130 => x"F0", 131 => x"00",
    132 => OP_CMP, 133 => x"00", 134 => x"00",
    135 => OP_BR_NZ, 136 => x"7E", 137 => x"00", -- Loop a 126
    
    -- VOLVER (Dir 138)
    138 => OP_JUMP, 139 => x"18", 140 => x"00", -- Ir a MENU (Dir 24)

    others => x"00"
  );

  signal RAM_DATA : t_mem_array := (others => x"00");

begin
    -- Memoria Split
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(Addr_in));
        
        if addr_int < 150 then
            Data_out <= ROM_CODE(addr_int) & ROM_CODE(addr_int + 1) & ROM_CODE(addr_int + 2);
        else
            Data_out <= RAM_DATA(addr_int) & RAM_DATA(addr_int + 1) & RAM_DATA(addr_int + 2);
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Solo escribir en zona segura (>= 150)
            if we = '1' and to_integer(unsigned(Addr_in)) >= 150 then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;

end architecture;