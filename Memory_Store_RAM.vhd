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
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05"; 
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08"; 
  constant OP_SUB   : std_logic_vector(7 downto 0) := x"09";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_DIV   : std_logic_vector(7 downto 0) := x"10"; 
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; 
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";
  constant OP_RAND  : std_logic_vector(7 downto 0) := x"14"; -- NUEVO OPCODE

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  -- MAPA DE VARIABLES
  constant R_SALDO     : std_logic_vector(7 downto 0) := x"F0";
  constant W_SALDO     : std_logic_vector(7 downto 0) := x"F2"; 
  constant R_MONTO     : std_logic_vector(7 downto 0) := x"F4"; 
  constant W_MONTO     : std_logic_vector(7 downto 0) := x"F6"; 
  constant R_ELECCION  : std_logic_vector(7 downto 0) := x"F8"; 
  constant W_ELECCION  : std_logic_vector(7 downto 0) := x"FA"; 
  constant R_RESULTADO : std_logic_vector(7 downto 0) := x"FC"; 
  constant W_RESULTADO : std_logic_vector(7 downto 0) := x"FE"; 

  constant ROM_CODE : t_mem_array := (
    -- 1. INICIALIZACIÓN
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => W_SALDO, 5 => x"00",      
    6 => OP_LDI, 7 => x"01", 8 => x"00",
    9 => OP_STX, 10 => W_MONTO, 11 => x"00",
    12 => OP_LDI, 13 => x"00", 14 => x"00",
    15 => OP_STX, 16 => W_ELECCION, 17 => x"00",

    -- 2. BARRERA DE SEGURIDAD
    18 => OP_LDIY, 19 => x"00", 20 => x"00", 
    21 => OP_LDX, 22 => x"F0", 23 => x"00", 
    24 => OP_CMP, 25 => x"00", 26 => x"00", 
    27 => OP_BR_NZ, 28 => x"15", 29 => x"00", 

    -- 3. MENÚ PRINCIPAL
    30 => OP_LDX, 31 => R_SALDO, 32 => x"00",      
    33 => OP_DISP, 34 => x"00", 35 => x"00",   
    36 => OP_LDI, 37 => x"10", 38 => x"00",
    39 => OP_STX, 40 => x"D0", 41 => x"00", 

    -- LEER INPUT
    42 => OP_LDX, 43 => x"F0", 44 => x"00", 
    45 => OP_LDIY, 46 => x"00", 47 => x"00", 
    48 => OP_CMP, 49 => x"00", 50 => x"00",
    51 => OP_BR_NZ, 52 => x"39", 53 => x"00",
    54 => OP_JUMP, 55 => x"2A", 56 => x"00",

    -- 4. PROCESAR TECLA
    57 => OP_LDIY, 58 => x"0F", 59 => x"00", 
    60 => OP_CMP, 61 => x"00", 62 => x"00",
    63 => OP_BR_NZ, 64 => x"45", 65 => x"00",
    66 => OP_JUMP, 67 => x"78", 68 => x"00", -- JUGAR

    -- Checar A
    69 => OP_LDIY, 70 => x"0A", 71 => x"00", 
    72 => OP_CMP, 73 => x"00", 74 => x"00",
    75 => OP_BR_NZ, 76 => x"57", 77 => x"00",
    78 => OP_LDI, 79 => x"00", 80 => x"00",   
    81 => OP_STX, 82 => W_ELECCION, 83 => x"00",
    84 => OP_JUMP, 85 => x"6F", 86 => x"00",

    -- Checar B
    87 => OP_LDIY, 88 => x"0B", 89 => x"00", 
    90 => OP_CMP, 91 => x"00", 92 => x"00",
    93 => OP_BR_NZ, 94 => x"69", 95 => x"00",
    96 => OP_LDI, 97 => x"01", 98 => x"00",   
    99 => OP_STX, 100 => W_ELECCION, 101 => x"00",
    102 => OP_JUMP, 103 => x"6F", 104 => x"00",

    -- Monto
    105 => OP_STX, 106 => W_MONTO, 107 => x"00", 
    108 => OP_JUMP, 109 => x"6F", 110 => x"00", 

    -- Feedback
    111 => OP_DISP, 112 => x"00", 113 => x"00", 
    114 => OP_WAIT, 115 => x"00", 116 => x"00", 
    117 => OP_JUMP, 118 => x"2A", 119 => x"00",

    -- 5. JUEGO: GIRAR RULETA
    120 => OP_LDI, 121 => x"20", 122 => x"00", 
    123 => OP_STX, 124 => x"D0", 125 => x"00", 
    126 => OP_WAIT, 127 => x"00", 128 => x"00", 
    129 => OP_WAIT, 130 => x"00", 131 => x"00",

    -- GENERAR RESULTADO (USANDO NUEVO OP_RAND)
    132 => OP_RAND, 133 => x"00", 134 => x"00", -- <--- AQUÍ ESTÁ LA SOLUCIÓN
    
    135 => OP_LDIY, 136 => x"26", 137 => x"00", -- Div 38
    138 => OP_DIV, 139 => x"00", 140 => x"00", 
    141 => OP_LDI, 142 => x"00", 143 => x"00", 
    144 => OP_ADD, 145 => x"00", 146 => x"00", 
    147 => OP_STX, 148 => W_RESULTADO, 149 => x"00",
    150 => OP_DISP, 151 => x"00", 152 => x"00", 

    -- 6. VERIFICAR: ¿PAR O IMPAR?
    153 => OP_LDIY, 154 => x"02", 155 => x"00", 
    156 => OP_DIV, 157 => x"00", 158 => x"00",  
    159 => OP_LDI, 160 => x"00", 161 => x"00", 
    162 => OP_ADD, 163 => x"00", 164 => x"00", 
    165 => OP_LDY, 166 => R_ELECCION, 167 => x"00", 
    168 => OP_CMP, 169 => x"00", 170 => x"00", 
    171 => OP_BR_NZ, 172 => x"C3", 173 => x"00", -- PERDER

    -- 7. GANAR
    174 => OP_LDI, 175 => x"40", 176 => x"00", 
    177 => OP_STX, 178 => x"D0", 179 => x"00",
    180 => OP_LDX, 181 => R_SALDO, 182 => x"00", 
    183 => OP_LDY, 184 => R_MONTO, 185 => x"00", 
    186 => OP_ADD, 187 => x"00", 188 => x"00", 
    189 => OP_JUMP, 190 => x"D2", 191 => x"00", 

    -- 8. PERDER
    195 => OP_LDI, 196 => x"50", 197 => x"00", 
    198 => OP_STX, 199 => x"D0", 200 => x"00",
    201 => OP_LDX, 202 => R_SALDO, 203 => x"00", 
    204 => OP_LDY, 205 => R_MONTO, 206 => x"00", 
    207 => OP_SUB, 208 => x"00", 209 => x"00", 

    -- 9. FIN
    210 => OP_STX, 211 => W_SALDO, 212 => x"00", 
    213 => OP_DISP, 214 => x"00", 215 => x"00", 
    216 => OP_WAIT, 217 => x"00", 218 => x"00", 
    219 => OP_WAIT, 220 => x"00", 221 => x"00", 

    -- 10. ENFRIAMIENTO SEGURO
    222 => OP_LDIY, 223 => x"00", 224 => x"00",
    225 => OP_LDX, 226 => x"F0", 227 => x"00",
    228 => OP_WAIT, 229 => x"00", 230 => x"00", 
    231 => OP_CMP, 232 => x"00", 233 => x"00",
    234 => OP_BR_NZ, 235 => x"DE", 236 => x"00", 
    237 => OP_JUMP, 238 => x"1E", 239 => x"00",

    others => x"00"
  );
  -- ... Resto del código de memoria igual ...