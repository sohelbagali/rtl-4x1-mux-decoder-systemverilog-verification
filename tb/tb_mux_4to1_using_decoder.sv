`timescale 1ns/1ps


// INTERFACE

interface mux_if(input logic clk);
    logic [3:0] in;
    logic [1:0] sel;
    logic y;
endinterface



// TRANSACTION

class transaction;
    rand logic [3:0] in;
    rand logic [1:0] sel;

    function void display(string tag);
        $display("[%0t][%s] IN=%b SEL=%0d", $time, tag, in, sel);
    endfunction
endclass



// GENERATOR

class generator;
    mailbox gen2drv;
    event scb_done;

    function new(mailbox gen2drv, event scb_done);
        this.gen2drv = gen2drv;
        this.scb_done = scb_done;
    endfunction

    task run(int n);
        repeat(n) begin
            transaction t = new();
            assert(t.randomize());
            t.display("GEN");
            gen2drv.put(t);
            @(scb_done);
        end
    endtask
endclass



// DRIVER

class driver;
    virtual mux_if vif;
    mailbox gen2drv;

    function new(virtual mux_if vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run(int n);
        transaction t;
        repeat(n) begin
            gen2drv.get(t);
            vif.in  = t.in;
            vif.sel = t.sel;
            @(posedge vif.clk);
        end
    endtask
endclass



// MONITOR

class monitor;
    virtual mux_if vif;
    mailbox mon2scb;

    function new(virtual mux_if vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run(int n);
        transaction t;
        repeat(n) begin
            @(posedge vif.clk);
            t = new();
            t.in  = vif.in;
            t.sel = vif.sel;
            t.display("MON");
            mon2scb.put(t);
        end
    endtask
endclass



// SCOREBOARD

class scoreboard;
    virtual mux_if vif;
    mailbox mon2scb;
    event scb_done;

    function new(virtual mux_if vif, mailbox mon2scb, event scb_done);
        this.vif = vif;
        this.mon2scb = mon2scb;
        this.scb_done = scb_done;
    endfunction

    task run(int n);
        transaction t;
        logic expected;

        repeat(n) begin
            mon2scb.get(t);
            #1;
            expected = t.in[t.sel];

            if (vif.y === expected)
                $display("SCB: PASS IN=%b SEL=%0d OUT=%b",
                         t.in, t.sel, vif.y);
            else
                $display("SCB: FAIL IN=%b SEL=%0d OUT=%b EXP=%b",
                         t.in, t.sel, vif.y, expected);

            -> scb_done;
        end
    endtask
endclass



// ENVIRONMENT

class tb_env;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox gen2drv, mon2scb;
    virtual mux_if vif;
    event scb_done;

    function new(virtual mux_if vif);
        this.vif = vif;
        gen2drv  = new(1);
        mon2scb  = new();
        gen      = new(gen2drv, scb_done);
        drv      = new(vif, gen2drv);
        mon      = new(vif, mon2scb);
        scb      = new(vif, mon2scb, scb_done);
    endfunction

    task run(int n);
        fork
            gen.run(n);
            drv.run(n);
            mon.run(n);
            scb.run(n);
        join
    endtask
endclass



// TOP TESTBENCH

module tb_mux_4to1_using_decoder;

    logic clk;
    mux_if intf(clk);
    tb_env env;

    mux_4to1_using_decoder dut (
        .in(intf.in),
        .sel(intf.sel),
        .y(intf.y)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(intf);
        env.run(10);
        #20;
        $finish;
    end

endmodule
