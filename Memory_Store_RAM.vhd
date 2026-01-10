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
  -- ROM: CÓDIGO DEL JUEGO (Direcciones 0 a 127)
  -- =========================================================
  constant ROM_CODE : t_mem_array := (
    -- 1. INICIALIZACIÓN (Solo tras Reset)
    -- Cargar 50 en X y guardarlo en RAM[x80]
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => x"80", 5 => x"00",      

    -- 2. MENÚ PRINCIPAL (Dir 6)
    -- Cargar Saldo de RAM (x80) antes de mostrar -> Arregla el 0000
    6 => OP_LDX, 7 => x"80", 8 => x"00",      
    9 => OP_DISP, 10 => x"00", 11 => x"00",   
    
    -- Configurar Matriz (A Roja)
    12 => OP_LDI, 13 => x"10", 14 => x"00",
    15 => OP_STX, 16 => x"D0", 17 => x"00", 

    -- 3. ESPERAR JUGADA (Dir 18)
    -- Leer Teclado
    18 => OP_LDX, 19 => x"F0", 20 => x"00", 
    
    -- Comparar con 0 (Limpiar Y primero)
    21 => OP_LDIY, 22 => x"00", 23 => x"00", 
    24 => OP_CMP, 25 => x"00", 26 => x"00",
    
    -- Si Hay Tecla (!= 0) -> IR A JUEGO (Dir 33 / x21)
    27 => OP_BR_NZ, 28 => x"21", 29 => x"00", 
    
    -- Si es 0 -> REPETIR (Dir 18 / x12)
    30 => OP_JUMP, 31 => x"12", 32 => x"00",  

    -- 4. JUEGO (Dir 33 / x21)
    -- Guardar Apuesta
    33 => OP_STX, 34 => x"82", 35 => x"00", 
    36 => OP_DISP, 37 => x"00", 38 => x"00", 

    -- Animación (Barras)
    39 => OP_LDI, 40 => x"20", 41 => x"00",
    42 => OP_STX, 43 => x"D0", 44 => x"00",
    
    -- Esperar Giro
    45 => OP_WAIT, 46 => x"00", 47 => x"00", 
    48 => OP_WAIT, 49 => x"00", 50 => x"00",
    
    -- Resultado Random
    51 => OP_LDX, 52 => x"E1", 53 => x"00", 
    54 => OP_DISP, 55 => x"00", 56 => x"00", 
    57 => OP_STX, 58 => x"83", 59 => x"00", 
    
    -- Comparar (Ganar/Perder)
    60 => OP_LDY, 61 => x"82", 62 => x"00", 
    63 => OP_CMP, 64 => x"00", 65 => x"00", 
    66 => OP_BR_NZ, 67 => x"51", 68 => x"00", -- Ir a PERDER (Dir 81)

    -- GANASTE (Dir 69)
    69 => OP_LDI, 70 => x"40", 71 => x"00", 
    72 => OP_STX, 73 => x"D0", 74 => x"00",
    75 => OP_LDI, 76 => x"99", 77 => x"00", -- Saldo 99
    78 => OP_JUMP, 79 => x"5A", 80 => x"00", -- Ir a FIN (Dir 90)

    -- PERDISTE (Dir 81 / x51)
    81 => OP_LDI, 82 => x"50", 83 => x"00", 
    84 => OP_STX, 85 => x"D0", 86 => x"00",
    87 => OP_LDI, 88 => x"0A", 89 => x"00", -- Saldo 10

    -- FIN Y ACTUALIZAR (Dir 90 / x5A)
    90 => OP_STX, 91 => x"80", 92 => x"00", -- Guardar Saldo
    93 => OP_WAIT, 94 => x"00", 95 => x"00", 

    -- ENFRIAMIENTO (Dir 96)
    96 => OP_LDIY, 97 => x"00", 98 => x"00",
    99 => OP_LDX, 100 => x"F0", 101 => x"00",
    102 => OP_CMP, 103 => x"00", 104 => x"00",
    105 => OP_BR_NZ, 106 => x"60", 107 => x"00", -- Si tecla sigue presionada, Loop a 96 (x60)
    
    -- VOLVER (Dir 108)
    108 => OP_JUMP, 109 => x"06", 110 => x"00", -- Ir a Dir 6 (Recarga saldo y vuelve al menú)

    others => x"00"
  );

  -- RAM: DATOS (Señales editables)
  signal RAM_DATA : t_mem_array := (others => x"00");

begin

    -- =========================================================
    -- LÓGICA DE MEMORIA SPLIT (SEPARADA)
    -- =========================================================
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(Addr_in));
        
        -- Si la dirección es baja (<128), leemos de la ROM (Código)
        if addr_int < 128 then
            Data_out <= ROM_CODE(addr_int) & 
                        ROM_CODE(addr_int + 1) & 
                        ROM_CODE(addr_int + 2);
        
        -- Si la dirección es alta (>=128), leemos de la RAM (Datos)
        else
            Data_out <= RAM_DATA(addr_int) & 
                        RAM_DATA(addr_int + 1) & 
                        RAM_DATA(addr_int + 2);
        end if;
    end process;

    -- ESCRITURA (Solo permitida en RAM)
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                -- Protección: Solo escribir si la dirección es >= 128
                if to_integer(unsigned(Addr_in)) >= 128 then
                    RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
                end if;
            end if;
        end if;
    end process;

end architecture;