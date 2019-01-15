function add_dyn(filename, casename)
% usage: add_dyn(filename, casename)
% filename defines the output file
% casename is the case to be loaded and modified
% 
% this script adds synthetic dynamic data to a ps case file
% eduardo cotilla-sanchez, january 2012. 
%
% Disabled all default branch quantities
%
%

% matlab metaphysics
rng(28);                        % Random number generator reset

% init constants and output
C = psconstants;                % File with power system constants

% check input file and load data
fprintf('adding dynamic data to %s ...\n',filename);
% load(filename,'ps'); *** Only for data stored in .mat files ***

ps = updateps(casename);

% ps = unify_generators(ps);
% set taps and shifters
% ps.branch(:,C.br.status)    = 1;
% ps.branch(:,C.br.tap)       = 1;
% ps.branch(:,C.br.shift)     = 0;

% convert loads
ps.shunt(:,C.sh.status)     = 1;
ps.shunt(:,C.sh.frac_Y)     = 0;
ps.shunt(:,C.sh.frac_S)     = 1;
ps.shunt(:,C.sh.frac_E)     = 0;
ps.shunt(:,C.sh.gamma)      = 0.08;

% run a power flow in order to set the correct power limits
opt = psoptions;
opt.nr.use_fsolve = true;
opt.verbose = true;
%ps = newpf(ps,opt);
%[ps.Ybus,ps.Yf,ps.Yt] = getYbus(ps,false);

if strcmp(filename,'case2383_mod_ps')
    % fix the Pmax,Pmin of the generators in this case, known issue for the base powerflow
    ps.gen(:,C.ge.Pmax)   = max(ps.gen(:,C.ge.Pg).*1.20, ps.gen(:,C.ge.Pmax));
    ps.gen(:,C.ge.Pmin)   = min(ps.gen(:,C.ge.Pg).*0.80, ps.gen(:,C.ge.Pmin));
    ps.gen([142 203],C.ge.Pmax)   = 0.5;
    ps.gen([142 203],C.ge.Pmin)   = 0;
    ps.gen([211 312],C.ge.Pmax)   = 4;
    ps.gen([211 312],C.ge.Pmin)   = 1;
    ps.gen(abs(ps.gen(:,C.ge.Pmin))<1e-6,C.ge.Pmin) = 0;
    ps.gen(abs(ps.gen(:,C.ge.Pg))<1e-6,C.ge.Pg) = 0;
    ps.gen(abs(ps.gen(:,C.ge.Pmax))<1e-6,C.ge.Pmax) = 0;
end

% initialize machine matrix
mac              = zeros(size(ps.gen,1),C.ma.cols);
mac(:,C.ma.gen)  = ps.gen(:,C.ge.bus);

% calculate mac parameters
mac(:,C.ma.M)   = ps.gen(:,C.ge.Pmax)/max(ps.gen(:,C.ge.Pmax))*140 + 10;                      
mac(:,C.ma.D)   = ps.gen(:,C.ge.Pmax)/max(ps.gen(:,C.ge.Pmax))*30 + 1 + 0.5*rand(size(ps.gen(:,C.ge.Pmax)));
mac(:,C.ma.Xd)  = 10./mac(:,C.ma.M) + 0.1*rand(size(mac(:,C.ma.M)));

xdpsmall_set        = ps.gen(:,C.ge.Pmax) <= 100;  xdplarge_set = ~xdpsmall_set;
mac(xdpsmall_set,C.ma.Xdp)     = mac(xdpsmall_set,C.ma.Xd)./8;
mac(xdplarge_set,C.ma.Xdp)     = mac(xdplarge_set,C.ma.Xd)./6;

xqsmall_set         = ps.gen(:,C.ge.Pmax) <= 300;  xqlarge_set = ~xqsmall_set;
mac(xqsmall_set,C.ma.Xq)        = mac(xqsmall_set,C.ma.Xd).*0.96;
mac(xqlarge_set,C.ma.Xq)        = mac(xqlarge_set,C.ma.Xd).*0.95;
mac(xqsmall_set,C.ma.Td0)       = 6;        % Added this and next line...
mac(xqlarge_set,C.ma.Td0)       = 5;
mac(xqsmall_set,C.ma.Td0p)      = 6;
mac(xqlarge_set,C.ma.Td0p)      = 5;


mac(:,C.ma.Xqp)     = mac(:,C.ma.Xq)./2;

% initialize exciter matrix
exc             = zeros(size(ps.gen,1),C.ex.cols); 
exc(:,C.ex.gen) = ps.gen(:,C.ge.bus);

% calculate exc parameters
exc(:,C.ex.type)    = 1;
exc(:,C.ex.Ka)      = 0;
exc(:,C.ex.Ta)      = 0.8 + 0.4.*rand(size(exc(:,C.ex.Ta))); 
exc(:,C.ex.Tb)      = 8 + 4.*rand(size(exc(:,C.ex.Tb)));
exc(:,C.ex.Ke)      = 80 + 40.*rand(size(exc(:,C.ex.Ke)));
exc(:,C.ex.Te)      = 0.08 + 0.04.*rand(size(exc(:,C.ex.Te)));
exc(:,C.ex.Urmax)   = 5;
exc(:,C.ex.Urmin)   = -5;

% initialize governor matrix
gov                 = zeros(size(ps.gen,1),C.go.cols);
gov(:,C.go.gen)     = ps.gen(:,C.ge.bus);

% calculate gov parameters
gov(:,C.go.type)    = 1;
gov(:,C.go.R)       = 0.04 + 0.02.*rand(size(gov(:,C.go.R)));
gov(:,C.go.Tt)      = 1.6 + 0.8.*rand(size(gov(:,C.go.Tt)));
gov(:,C.go.LCmax)   = 100;      % Changed to 100 from 10
gov(:,C.go.LCmin)   = -100;     % Changed to -100 from -10
gov(:,C.go.Pmax)    = ps.gen(:,C.ge.Pmax)./ps.baseMVA;
gov(:,C.go.Pmin)    = 0;
gov(:,C.go.Ti)      = 4;        % TH - Added to match case39

% save & finalize
ps.mac = mac; 
ps.exc = exc;
ps.gov = gov;

ps = updateps(ps);
save(filename,'ps');        % Modified to use user input name
fprintf('dynamic data appended to %s. \n',filename);
