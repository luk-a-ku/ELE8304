-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-- Polytechnique Montréal
-------------------------------------------------------------------------------
-- File     riscv_adder_tb.vhd
-- Author   Khalil Ben Salem  <khalil.ben-salem@polymtl.ca>
-- Date     2026-10-26
-------------------------------------------------------------------------------
-- Description 	adder_tb with ripple-carry
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity riscv_adder_tb is    --Compare cette entité avec celle de l'additionneur
end entity riscv_adder_tb;   --le testbench va créer des valeurs pour les entrees et sorties

architecture tb of riscv_adder_tb is

    constant N : positive := 32;

    signal i_a    : std_logic_vector(N-1 downto 0) := (others => '0');  --signifie que tous les bits sont initialisés à zéro au début de la simulation
    signal i_b    : std_logic_vector(N-1 downto 0) := (others => '0');
    signal i_sign : std_logic := '0';
    signal i_sub  : std_logic := '0';
    signal o_sum  : std_logic_vector(N downto 0);

begin

    dut : entity work.riscv_adder
        generic map (
            N => N
        )
        port map (
            i_a    => i_a,
            i_b    => i_b,
            i_sign => i_sign,
            i_sub  => i_sub,
            o_sum  => o_sum
        );

    stimulus : process
    begin

        -- Test 1 : addition non signee, 10 + 3 = 13
        i_sign <= '0';
        i_sub  <= '0';
        i_a    <= x"0000000A";
        i_b    <= x"00000003";
        wait for 1 ns;

        assert o_sum = std_logic_vector(to_unsigned(13, N+1))
            report "ERREUR : 10 + 3"
            severity error;

        -- Test 2 : soustraction non signee, 10 - 3 = 7
        i_sub <= '1';
        wait for 1 ns;

        assert o_sum = std_logic_vector(to_unsigned(7, N+1))
            report "ERREUR : 10 - 3"
            severity error;

        -- Test 3 : soustraction avec A < B, 3 - 10
        i_a <= x"00000003";
        i_b <= x"0000000A";
        wait for 1 ns;

        assert o_sum = ('1' & x"FFFFFFF9")
            report "ERREUR : 3 - 10"
            severity error;

        -- Test 4 : debordement non signe, FFFFFFFF + 1
        i_sub <= '0';
        i_a   <= x"FFFFFFFF";
        i_b   <= x"00000001";
        wait for 1 ns;

        assert o_sum = ('1' & x"00000000")
            report "ERREUR : addition avec retenue finale"
            severity error;

        -- Test 5 : addition signee, -3 + 2 = -1
        i_sign <= '1';
        i_a    <= x"FFFFFFFD";
        i_b    <= x"00000002";
        wait for 1 ns;

        assert o_sum = ('1' & x"FFFFFFFF")
            report "ERREUR : -3 + 2"
            severity error;

        -- Test 6 : soustraction signee, -3 - 2 = -5
        i_sub <= '1';
        wait for 1 ns;

        assert o_sum = ('1' & x"FFFFFFFB")
            report "ERREUR : -3 - 2"
            severity error;

        report "Tests de l'additionneur termines."
            severity note;

        stop;
        wait;

    end process stimulus;

end architecture tb;
