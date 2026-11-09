-------------------------------------------------------------------------------
-- ESWP : inversion des QUATRE OCTETS d'un mot de 32 bits, sans inverser
-- les bits de chaque octet. Exemple : 12345678 -> 78563412.
-- La permutation est identique dans les deux sens (LE->BE et BE->LE).
-- Le Core decode funct3 : bit 2 = choix registre / immediat ; bit 0 = sens.
-- Le sens ne change pas le cablage : appliquer deux fois ESWP rend l'original.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity riscv_eswp is
    port (
        i_data : in  std_logic_vector(31 downto 0);
        o_res  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of riscv_eswp is
begin
    o_res <= i_data(7 downto 0) & i_data(15 downto 8) &
             i_data(23 downto 16) & i_data(31 downto 24);
end architecture;
