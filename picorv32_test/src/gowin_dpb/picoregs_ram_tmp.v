//Copyright (C)2014-2022 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: V1.9.8.09 Education
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18C
//Created Time: Thu Mar 09 08:38:45 2023

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    picoregs_ram your_instance_name(
        .douta(douta_o), //output [31:0] douta
        .doutb(doutb_o), //output [31:0] doutb
        .clka(clka_i), //input clka
        .ocea(ocea_i), //input ocea
        .cea(cea_i), //input cea
        .reseta(reseta_i), //input reseta
        .wrea(wrea_i), //input wrea
        .clkb(clkb_i), //input clkb
        .oceb(oceb_i), //input oceb
        .ceb(ceb_i), //input ceb
        .resetb(resetb_i), //input resetb
        .wreb(wreb_i), //input wreb
        .ada(ada_i), //input [4:0] ada
        .dina(dina_i), //input [31:0] dina
        .adb(adb_i), //input [4:0] adb
        .dinb(dinb_i) //input [31:0] dinb
    );

//--------Copy end-------------------
