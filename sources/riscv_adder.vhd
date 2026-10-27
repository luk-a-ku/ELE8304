-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-- Polytechnique Montréal
-------------------------------------------------------------------------------
-- File     riscv_adder.vhd
-- Author   Khalil Ben Salem  <khalil.ben-salem@polymtl.ca>
-- Date     2026-10-26
-------------------------------------------------------------------------------
-- Description 	adder with ripple-carry
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_adder is
  generic (
    N : positive := 32
  );
  port (
    i_a    : in  std_logic_vector(N-1 downto 0);
    i_b    : in  std_logic_vector(N-1 downto 0);
    i_sign : in  std_logic;
    i_sub  : in  std_logic;
    o_sum  : out std_logic_vector(N downto 0)
  );
end entity riscv_adder;

architecture beh of riscv_adder is
--------------------------------------
--------- COMPLETE FROM HERE ---------

    -- Operandes et resultat etendus sur N+1 bits
    signal a_ext     : std_logic_vector(N downto 0);
    signal b_ext     : std_logic_vector(N downto 0);
    signal b_operand : std_logic_vector(N downto 0);

    -- Retenues de l'additionneur
    signal carry     : std_logic_vector(N+1 downto 0);

    -- Somme intermediaire
    signal sum_int   : std_logic_vector(N downto 0);

begin

    -- Extension des operandes : signee ou non signee
    process(i_a, i_b, i_sign)
    begin
        if i_sign = '1' then
            a_ext <= i_a(N-1) & i_a;   --Le bit de signe est recopié à gauche
            b_ext <= i_b(N-1) & i_b;
        else
            a_ext <= '0' & i_a;        --Extension par zéro pour les nombres non signés
            b_ext <= '0' & i_b;
        end if;
    end process;

    -- Inversion de B pour la soustraction
    b_operand <= not b_ext when i_sub = '1'
                 else b_ext;

    -- Retenue initiale : 1 pour soustraire, 0 pour additionner
    carry(0) <= i_sub;   -- ( A - B = A + !B + 1 )

    -- Additionneur a propagation de retenue (ripple-carry)
    gen_adder : for k in 0 to N generate

        sum_int(k) <= a_ext(k) xor b_operand(k) xor carry(k);  --Résultat vaut 1 lorsqu'un nombre impair des bits d'entrée vaut 1

        carry(k+1) <=
            (a_ext(k) and b_operand(k)) or
            ((a_ext(k) xor b_operand(k)) and carry(k));

    end generate gen_adder;

    -- Resultat sur N+1 bits
    o_sum <= sum_int;

end architecture beh;