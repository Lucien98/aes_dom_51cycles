function integer _blind_nrnd(input integer d);
begin
if (d==1) _blind_nrnd = 1; // Hack to avoid 0-width signals.
else if (d==2) _blind_nrnd = d-1;
else _blind_nrnd = d;
end
endfunction
`define RAND_OPT
