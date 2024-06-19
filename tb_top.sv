/**
`include "uvm_macros.svh"
import uvm_pkg::*;



class dff_seq_item extends uvm_sequence_item;

    rand logic rst;
    rand logic din;
    logic dout;
    
    `uvm_object_utils_begin(dff_seq_item)
        `uvm_field_int(rst, UVM_ALL_ON)
        `uvm_field_int(din, UVM_ALL_ON)
        `uvm_field_int(dout, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new( string name = "dff_seq_item" );
        super.new(name);
    endfunction:new
    
    //constraint in_c { rst == 1'b0; }

endclass:dff_seq_item



class dff_sequence extends uvm_sequence#(dff_seq_item);

    dff_seq_item req;

    `uvm_object_utils(dff_sequence)
    
    function new( string name = "dff_sequence" );
        super.new(name);
    endfunction:new
    
    /*function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        req = dff_seq_item::type_id::create("req");
    endfunction:build_phase*/
    
    /*
    task body();
        forever begin
            req = dff_seq_item::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            req.print();
            finish_item(req);
        end
    endtask:body
    
endclass:dff_sequence


class dff_sequencer extends uvm_sequencer#(dff_seq_item);

    `uvm_component_utils(dff_sequencer)
    
    function new( string name  = "dff_sequencer", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
endclass:dff_sequencer


class dff_driver extends uvm_driver#(dff_seq_item);

    dff_seq_item req;

    virtual dff_interface vif_drv;

    `uvm_component_utils(dff_driver)
    
    function new( string name = "dff_driver", uvm_component parent);
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#( virtual dff_interface )::get(this, "", "dff_interface", vif_drv))
            `uvm_fatal(get_type_name(), "Can't get the interface")
        req = dff_seq_item::type_id::create("req");
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            drive();
            seq_item_port.item_done();
        end
    endtask:run_phase
    
    task drive();
        @(posedge vif_drv.clk);
            vif_drv.rst <= req.rst;
            vif_drv.din <= req.din;
            //@(posedge vif_drv.clk);
    endtask:drive
    

endclass:dff_driver



class dff_monitor extends uvm_monitor;

    virtual dff_interface vif_mon;
    
    dff_seq_item mon_item;
    
    uvm_analysis_port#(dff_seq_item) mon_ap;
    
    `uvm_component_utils(dff_monitor)
    
    function new(string name = "dff_monitor", uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dff_interface)::get(this, "", "dff_interface", vif_mon))
            `uvm_fatal(get_type_name(), "Can't get the interface")
        mon_item = dff_seq_item::type_id::create("mon_item");
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
    forever begin
        wait(!vif_mon.rst);
            @(posedge vif_mon.clk);
                mon_item.rst = vif_mon.rst;
                mon_item.din = vif_mon.din;
            @(posedge vif_mon.clk);
                mon_item.dout = vif_mon.dout;
                
        mon_ap.write(mon_item);
        mon_item.print();
    end
    
    endtask:run_phase
    
    
        
endclass:dff_monitor            


class dff_agent extends uvm_agent;

    dff_sequencer seqr;
    dff_driver drvr;
    dff_monitor mon;

    `uvm_component_utils(dff_agent)
    
    function new( string name = "dff_agent", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = dff_sequencer::type_id::create("seqr", this);
        drvr  = dff_driver::type_id::create("drvr", this);
        mon = dff_monitor::type_id::create("mon", this);
    endfunction:build_phase
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drvr.seq_item_port.connect(seqr.seq_item_export);
    endfunction:connect_phase

endclass:dff_agent



class dff_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dff_scoreboard)

    uvm_analysis_imp#(dff_seq_item, dff_scoreboard) sb_imp;
    
    dff_seq_item transactions[$];
    
    function new( string name = "dff_scoreboard", uvm_component parent );
        super.new(name, parent);
        sb_imp = new("sb_imp", this);
    endfunction:new
    
    function void write(dff_seq_item item);
        transactions.push_back(item);
    endfunction:write
    
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        forever begin
            dff_seq_item curr_trans;
            wait((transactions.size() != 0));
            curr_trans = transactions.pop_front();
            compare(curr_trans);
        end
            
    endtask:run_phase
    
    task compare(dff_seq_item curr_trans);
        logic actual;
        logic expected;
        
        if(!curr_trans.rst)
            expected = curr_trans.din;
            
        if(curr_trans.rst)
            expected = 1'b0;
            
        actual = curr_trans.dout;
        
        if(actual == expected)
            `uvm_info("COMPARE PASSED", $sformatf("rst = %0d, din = %0d, dout = %0d", curr_trans.rst, curr_trans.din, curr_trans.dout), UVM_LOW)
        else
            `uvm_info("COMPARE FAILED", $sformatf("rst = %0d, din = %0d, dout = %0d", curr_trans.rst, curr_trans.din, curr_trans.dout), UVM_LOW)
    endtask:compare


endclass:dff_scoreboard



class dff_env extends uvm_env;

    `uvm_component_utils(dff_env)
    
    dff_agent agt;
    dff_scoreboard sb;
    
    function new( string name = "dff_env", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = dff_agent::type_id::create("dff_agent", this);
        sb = dff_scoreboard::type_id::create("dff_scoreboard", this);
    endfunction:build_phase
    
    function void connect_phase(uvm_phase phase);
        agt.mon.mon_ap.connect(sb.sb_imp);
    endfunction:connect_phase
    
endclass:dff_env


class dff_test extends uvm_test;

    dff_env env;
    
    dff_sequence seq;
    
    `uvm_component_utils(dff_test)
    
    function new(string name = "dff_test", uvm_component parent);
        super.new(name,parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);    
        env = dff_env::type_id::create("env", this);
        seq = dff_sequence::type_id::create("seq", this);
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            repeat(20)
            begin
                seq.start(env.agt.seqr);
            end
    endtask:run_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction:end_of_elaboration_phase
        
endclass:dff_test



interface dff_interface( input logic clk );
    
    logic rst;
    logic din;
    logic dout;
    
endinterface:dff_interface

module tb_top;

    logic clk;
    
    dff_interface intf(.clk(clk));
    
    dff_new_uvm DUT (
                        intf.clk,
                        intf.rst,
                        intf.din,
                        intf.dout
                    );
                    
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end
    
    initial begin
        uvm_config_db#(virtual dff_interface)::set(null, "*", "dff_interface", intf);
    end
    
    initial begin
    run_test("dff_test");
    end
    
                  
endmodule:tb_top
         */
         
         
         
         
         
`include "uvm_macros.svh"
import uvm_pkg::*;



class dff_seq_item extends uvm_sequence_item;

    rand logic rst;
    rand logic din;
    logic dout;
    
    `uvm_object_utils_begin(dff_seq_item)
        `uvm_field_int(rst, UVM_ALL_ON)
        `uvm_field_int(din, UVM_ALL_ON)
        `uvm_field_int(dout, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new( string name = "dff_seq_item" );
        super.new(name);
    endfunction:new
    
    //constraint in_c { soft rst == 1'b0; }

endclass:dff_seq_item



class dff_sequence extends uvm_sequence#(dff_seq_item);

    dff_seq_item req;

    `uvm_object_utils(dff_sequence)
    
    function new( string name = "dff_sequence" );
        super.new(name);
    endfunction:new
    
    /*function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        req = dff_seq_item::type_id::create("req");
    endfunction:build_phase*/
    
    
    task body();
        forever begin
            req = dff_seq_item::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            //req.print();
            finish_item(req);
        end
    endtask:body
    
endclass:dff_sequence



/*
class dff_sequence1 extends uvm_sequence#(dff_seq_item);

    dff_seq_item req1;

    `uvm_object_utils(dff_sequence1)
    
    function new( string name = "dff_sequence1" );
        super.new(name);
    endfunction:new
    
    /*function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        req = dff_seq_item::type_id::create("req");
    endfunction:build_phase*/
    
    /*
    task body();
        forever begin
            req1 = dff_seq_item::type_id::create("req1, this");
            start_item(req1);
            assert(req.randomize() with {req.rst == 1'b1;});
            //req.print();
            finish_item(req1);
        end
    endtask:body
    
endclass:dff_sequence1*/

class dff_sequencer extends uvm_sequencer#(dff_seq_item);

    `uvm_component_utils(dff_sequencer)
    
    function new( string name  = "dff_sequencer", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
endclass:dff_sequencer


class dff_driver extends uvm_driver#(dff_seq_item);

    dff_seq_item req;

    virtual dff_interface vif_drv;

    `uvm_component_utils(dff_driver)
    
    function new( string name = "dff_driver", uvm_component parent);
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#( virtual dff_interface )::get(this, "", "dff_interface", vif_drv))
            `uvm_fatal(get_type_name(), "Can't get the interface")
        req = dff_seq_item::type_id::create("req");
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            drive();
            seq_item_port.item_done();
        end
    endtask:run_phase
    
    task drive();
        @(posedge vif_drv.clk);
            vif_drv.rst <= req.rst;
            vif_drv.din <= req.din;
            //@(posedge vif_drv.clk);
    endtask:drive
    

endclass:dff_driver



class dff_monitor extends uvm_monitor;

    virtual dff_interface vif_mon;
    
    dff_seq_item mon_item;
    
    uvm_analysis_port#(dff_seq_item) mon_ap;
    
    `uvm_component_utils(dff_monitor)
    
    function new(string name = "dff_monitor", uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual dff_interface)::get(this, "", "dff_interface", vif_mon))
            `uvm_fatal(get_type_name(), "Can't get the interface")
        mon_item = dff_seq_item::type_id::create("mon_item");
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
    forever begin
        wait(!vif_mon.rst);
            @(posedge vif_mon.clk);
                mon_item.rst = vif_mon.rst;
                mon_item.din = vif_mon.din;
            @(posedge vif_mon.clk);
                mon_item.dout = vif_mon.dout;
                
        mon_ap.write(mon_item);
        //mon_item.print();
        `uvm_info("MON_DATA", $sformatf("rst = %0d, din = %0d, dout = %0d", mon_item.rst, mon_item.din, mon_item.dout), UVM_LOW)
    end
    
    endtask:run_phase
    
    
        
endclass:dff_monitor            



class dff_agent_config extends uvm_object;

    `uvm_object_utils(dff_agent_config)
    
    uvm_active_passive_enum is_active;

    function new( string name = "dff_agent_config" );
        super.new(name);
    endfunction:new
    
endclass:dff_agent_config    
    
class dff_agent extends uvm_agent;

    dff_agent_config a_cfg;

    dff_sequencer seqr;
    dff_driver drvr;
    dff_monitor mon;

    `uvm_component_utils(dff_agent)
    
    function new( string name = "dff_agent", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(dff_agent_config)::get(this, "", "dff_agent_config", a_cfg))
            `uvm_fatal(get_type_name(), "Can't get the configuration data (is.active)")
        mon = dff_monitor::type_id::create("mon", this);
        
        if(a_cfg.is_active == UVM_ACTIVE) begin
            seqr = dff_sequencer::type_id::create("seqr", this);
            drvr  = dff_driver::type_id::create("drvr", this);
        end
    endfunction:build_phase
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(a_cfg.is_active == UVM_ACTIVE)begin
            drvr.seq_item_port.connect(seqr.seq_item_export);
        end
    endfunction:connect_phase

endclass:dff_agent





class dff_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dff_scoreboard)

    uvm_analysis_imp#(dff_seq_item, dff_scoreboard) sb_imp;
    
    dff_seq_item transactions[$];
    
    function new( string name = "dff_scoreboard", uvm_component parent );
        super.new(name, parent);
        sb_imp = new("sb_imp", this);
    endfunction:new
    
    function void write(dff_seq_item item);
        transactions.push_back(item);
    endfunction:write
    
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        forever begin
            dff_seq_item curr_trans;
            wait((transactions.size() != 0));
            curr_trans = transactions.pop_front();
            compare(curr_trans);
        end
            
    endtask:run_phase
    
    task compare(dff_seq_item curr_trans);
        logic actual;
        logic expected;
        
        if(!curr_trans.rst)
            expected = curr_trans.din;
            
        if(curr_trans.rst)
            expected = 1'b0;
            
        actual = curr_trans.dout;
        
        if(actual == expected)
            `uvm_info("COMPARE PASSED", $sformatf("rst = %0d, din = %0d, dout = %0d", curr_trans.rst, curr_trans.din, curr_trans.dout), UVM_LOW)
        else
            `uvm_info("COMPARE FAILED", $sformatf("rst = %0d, din = %0d, dout = %0d", curr_trans.rst, curr_trans.din, curr_trans.dout), UVM_LOW)
    endtask:compare


endclass:dff_scoreboard



class dff_env extends uvm_env;

    `uvm_component_utils(dff_env)
    
    dff_agent agt;
    dff_scoreboard sb;
    
    function new( string name = "dff_env", uvm_component parent );
        super.new(name, parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = dff_agent::type_id::create("dff_agent", this);
        sb = dff_scoreboard::type_id::create("dff_scoreboard", this);
    endfunction:build_phase
    
    function void connect_phase(uvm_phase phase);
        agt.mon.mon_ap.connect(sb.sb_imp);
    endfunction:connect_phase
    
endclass:dff_env


class dff_test extends uvm_test;

    dff_agent_config a_cfg;

    dff_env env;
    
    dff_sequence seq;
    
    //dff_sequence1 seq1;
    
    `uvm_component_utils(dff_test)
    
    function new(string name = "dff_test", uvm_component parent);
        super.new(name,parent);
    endfunction:new
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);    
        a_cfg = dff_agent_config::type_id::create("a_cfg");
        a_cfg.is_active = UVM_ACTIVE;
        uvm_config_db#(dff_agent_config)::set(this, "*", "dff_agent_config", a_cfg);
        env = dff_env::type_id::create("env", this);
        seq = dff_sequence::type_id::create("seq", this);
        //seq1 = dff_sequence1::type_id::create("seq1", this);
    endfunction:build_phase
    
    task run_phase(uvm_phase phase);
       /* phase.raise_objection(this);
            repeat(10)
            begin
                seq1.start(env.agt.seqr);
            end
        phase.drop_objection(this);*/
        phase.raise_objection(this);
            repeat(10)
            begin
                seq.start(env.agt.seqr);
            end
        phase.drop_objection(this);
           

    endtask:run_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction:end_of_elaboration_phase
        
endclass:dff_test



interface dff_interface( input logic clk );
    
    logic rst;
    logic din;
    logic dout;
    
endinterface:dff_interface

module tb_top;

    logic clk;
    
    dff_interface intf(.clk(clk));
    
    dff_new_uvm DUT (
                        intf.clk,
                        intf.rst,
                        intf.din,
                        intf.dout
                    );
                    
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end
    
    initial begin
        uvm_config_db#(virtual dff_interface)::set(null, "*", "dff_interface", intf);
    end
    
    initial begin
    run_test("dff_test");
    end
    
                  
endmodule:tb_top        
         
         
        