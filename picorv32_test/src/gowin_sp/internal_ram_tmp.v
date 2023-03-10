//Copyright (C)2014-2022 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: V1.9.8.09 Education
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18C
//Created Time: Thu Mar 09 08:38:05 2023

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    internal_ram your_instance_name(
        .dout(dout_o), //output [31:0] dout
        .clk(clk_i), //input clk
        .oce(oce_i), //input oce
        .ce(ce_i), //input ce
        .reset(reset_i), //input reset
        .wre(wre_i), //input wre
        .ad(ad_i), //input [9:0] ad
        .din(din_i) //input [31:0] din
    );

//--------Copy end-------------------
