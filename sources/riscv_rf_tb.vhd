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

architecture sim of riscv_rf_tb is 

	constant REG_WIDTH : integer := 5;
	constant XLEN : integer := 32;


	signal o_clk     : std_logic := '0';
    signal o_rstn    : std_logic := '0';
    signal o_we      : std_logic := '0';
	
    signal o_addr_w  : std_logic_vector(REG_WIDTH-1 downto 0);
					 := (others => '0');	
    signal o_addr_ra : std_logic_vector(REG_WIDTH-1 downto 0) 
					 := (others => '0');
    signal o_addr_rb : std_logic_vector(REG_WIDTH-1 downto 0);
					 := (others => '0');
    signal o_data_w  : std_logic_vector(XLEN-1 downto 0));
					 := (others => '0');
					 
    signal i_data_ra : std_logic_vector(XLEN-1 downto 0);
    signal i_data_rb : std_logic_vector(XLEN-1 downto 0);
	
	
	constant PERIOD   : time := 100 ns;

begin

	dut : entity work.riscv_rf
		port map (
			i_clk    	=> 	o_clk    
			i_rstn   	=> 	o_rstn   
			i_we     	=> 	o_we     
			i_addr_ra	=> 	o_addr_ra
			o_data_ra	=> 	i_data_ra
			i_addr_rb	=> 	o_addr_rb
			o_data_rb	=> 	i_data_rb
			i_addr_w 	=> 	o_addr_w 
			i_data_w 	=> 	o_data_w 
		);
		
		o_clk <= not o_clk after PERIOD/2;
		
		stimulus : process
			



end architecture sim;