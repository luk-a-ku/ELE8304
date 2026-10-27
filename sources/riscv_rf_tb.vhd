-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-------------------------------------------------------------------------------
-- File     riscv_rf_tb.vhd
-- Author   Luc M'PO  <mpoluc@yahoo.com>
-- Date     2026-10-21
-------------------------------------------------------------------------------
-- Brief    Test Bench for Register File
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_pkg.all;

entity riscv_rf_tb is
end entity riscv_rf_tb;

architecture tb of riscv_rf_tb is

  constant CLK_PERIOD : time    := 10 ns;
  constant NB_REG     : natural := 2**REG_WIDTH;
  constant ZERO       : std_logic_vector(XLEN-1 downto 0) := (others => '0');

  signal clk     : std_logic := '0';
  signal rstn    : std_logic := '0';
  signal we      : std_logic := '0';
  signal addr_ra : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');
  signal addr_rb : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');
  signal addr_w  : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');
  signal data_w  : std_logic_vector(XLEN-1 downto 0)      := (others => '0');
  signal data_ra : std_logic_vector(XLEN-1 downto 0);
  signal data_rb : std_logic_vector(XLEN-1 downto 0);

  signal sim_end : boolean := false;

begin

  dut : entity work.riscv_rf
    port map (
      i_clk     => clk,
      i_rstn    => rstn,
      i_we      => we,
      i_addr_ra => addr_ra,
      o_data_ra => data_ra,
      i_addr_rb => addr_rb,
      o_data_rb => data_rb,
      i_addr_w  => addr_w,
      i_data_w  => data_w);

  clk <= not clk after CLK_PERIOD/2 when not sim_end else '0';

  p_stim : process
  begin

    rstn <= '0';
    wait until falling_edge(clk);
    rstn <= '1';

    for i in 0 to NB_REG-1 loop
      addr_ra <= std_logic_vector(to_unsigned(i, REG_WIDTH));
      addr_rb <= std_logic_vector(to_unsigned(i, REG_WIDTH));
      wait until falling_edge(clk);
      assert data_ra = ZERO and data_rb = ZERO
        report "Test 1 : registre " & integer'image(i) & " non nul apres reset"
        severity error;
    end loop;

    we <= '1';
    for i in 1 to NB_REG-1 loop
      addr_w <= std_logic_vector(to_unsigned(i, REG_WIDTH));
      data_w <= std_logic_vector(to_unsigned(i * 1000, XLEN));
      wait until falling_edge(clk);
    end loop;
    we <= '0';

    for i in 1 to NB_REG-1 loop
      addr_ra <= std_logic_vector(to_unsigned(i, REG_WIDTH));
      addr_rb <= std_logic_vector(to_unsigned(NB_REG-i, REG_WIDTH));
      wait until falling_edge(clk);
      assert data_ra = std_logic_vector(to_unsigned(i * 1000, XLEN))
        report "Test 2 : mauvaise valeur sur le port A, registre "
               & integer'image(i)
        severity error;
      assert data_rb = std_logic_vector(to_unsigned((NB_REG-i) * 1000, XLEN))
        report "Test 2 : mauvaise valeur sur le port B, registre "
               & integer'image(NB_REG-i)
        severity error;
    end loop;

    we      <= '1';
    addr_w  <= "00000";
    data_w  <= x"FFFFFFFF";
    addr_ra <= "00000";
    addr_rb <= "00000";
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
    assert data_ra = ZERO and data_rb = ZERO
      report "Test 3 : x0 a ete modifie" severity error;

    we      <= '0';
    addr_w  <= "00101";              
    data_w  <= x"12345678";
    addr_ra <= "00101";
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    assert data_ra = std_logic_vector(to_unsigned(5000, XLEN))
      report "Test 5 : x5 modifie alors que i_we = 0" severity error;

    we      <= '1';
    addr_w  <= "00011";              
    data_w  <= x"AAAA5555";
    addr_ra <= "00011";              
    addr_rb <= "00100";              
    wait until falling_edge(clk);
    we <= '0';
    assert data_ra = x"AAAA5555"
      report "Test 6 : pas de forwarding sur le port A" severity error;
    assert data_rb = std_logic_vector(to_unsigned(4000, XLEN))
      report "Test 6 : le port B ne devait pas etre forwarde" severity error;

    we      <= '1';
    addr_w  <= "10100";              
    data_w  <= x"0F0F0F0F";
    addr_ra <= "10100";
    addr_rb <= "10100";
    wait until falling_edge(clk);
    we <= '0';
    assert data_ra = x"0F0F0F0F" and data_rb = x"0F0F0F0F"
      report "Test 7 : pas de forwarding sur les deux ports" severity error;

    wait until falling_edge(clk);
    assert data_ra = x"0F0F0F0F" and data_rb = x"0F0F0F0F"
      report "Test 7 : x20 mal ecrit" severity error;

    report "Fin de la simulation de riscv_rf_tb";
    sim_end <= true;
    wait;
  end process p_stim;

end architecture tb;