`include "blind.vh"
localparam blind_n_rnd = _blind_nrnd(d);
localparam rnd_bus0 = 2*d*(d-1);
localparam rnd_bus1 = 1*d*(d-1) + 2*blind_n_rnd;
`ifndef RAND_OPT
localparam rnd_bus2 = 2*d*(d-1) + 4*blind_n_rnd;
`else
localparam rnd_bus2 = 2*d*(d-1) + 2*blind_n_rnd;
`endif
localparam rnd_bus3 = 4*d*(d-1);
