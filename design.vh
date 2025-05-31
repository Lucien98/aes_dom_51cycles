`include "sbox/blind.vh"
localparam blind_n_rnd = _blind_nrnd(d);
localparam bcoeff = _bcoeff(d);
localparam rnd_bus0 = 2*d*(d-1);
localparam rnd_bus1 = 1*d*(d-1);
localparam rnd_bus2 = 2*d*(d-1) + bcoeff*blind_n_rnd;
localparam rnd_bus3 = 4*d*(d-1);
