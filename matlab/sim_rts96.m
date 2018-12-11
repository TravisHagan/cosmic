function sim_rts96
%{

RTS 96 simulation

case file: rts96_ps

Errant tripping on temperature relays for most branches,
set time to 1e6 from 0



%}
%% Simulate RTS 96
clear all; close all; clc;

t_max = 5;         % Simulation time

if ~(ismcc || isdeployed)
    addpath('../data');
    addpath('../numerics');
end

C = psconstants;
opt = psoptions;
opt.sim.resuming_sim = 0;       % 0 - not resuming case, 1 - loads value from a previous simulation


if opt.sim.resuming_sim == 0
    load('rts96.mat','ps')
    x_in = [];
    y_in = [];
else
    [ps, x_in, y_in] = load_sim_state();
end

% to differentiate the line MVA ratings
rateB_rateA = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
rateC_rateA = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
ps.branch(rateB_rateA == 1,C.br.rateB) = 1.1*ps.branch(rateB_rateA == 1,C.br.rateA);
ps.branch(rateC_rateA == 1,C.br.rateC) = 1.5*ps.branch(rateC_rateA == 1,C.br.rateA);

% set some options
opt.sim.integration_scheme      = 1;
opt.sim.dt_default              = 1/60;
opt.nr.use_fsolve               = true;
% opt.pf.linesearch             = 'cubic_spline';
opt.verbose                     = true;
opt.sim.gen_control = 1;        % 0 = generator without exciter and governor, 1 = generator with exciter and governor
opt.sim.angle_ref = 0;          % 0 = delta_sys, 1 = center of inertia---delta_coi
                                % Center of inertia doesn't work when having islanding
opt.sim.COI_weight = 0;         % 1 = machine inertia, 0 = machine MVA base(Powerworld)
opt.sim.uvls_tdelay_ini = 0.5;  % 1 sec delay for uvls relay.
opt.sim.ufls_tdelay_ini = 0.5;  % 1 sec delay for ufls relay.
opt.sim.dist_tdelay_ini = 0.5;  % 1 sec delay for dist relay.
opt.sim.temp_tdelay_ini = 1e6;    % 0 sec delay for temp relay.

opt.sim.var_step = false;       % Use fixed step size
% Don't forget to change this value (opt.sim.time_delay_ini) in solve_dae.m

opt.sim.var_step = 1/60;
opt.sim.dt_max_default = 1/60;


% ps = unify_generators(ps);
% ps.branch(:,C.br.tap)       = 1;
% ps.shunt(:,C.sh.factor)     = 1;    % C.sh.factor is the same as C.sh.status
ps.shunt(:,C.sh.status)     = 1;
ps.shunt(:,C.sh.frac_S)     = 1;
ps.shunt(:,C.sh.frac_E)     = 0;
ps.shunt(:,C.sh.frac_Z)     = 0;
ps.shunt(:,C.sh.gamma)      = 0.08;

%% Initialize the case

% Only update if this is a new case
if opt.sim.resuming_sim == 0        % If this isn't a continuation...
    [ps, ~, ~] = newpf(ps,opt);
    
    [ps.Ybus, ps.Yf, ps.Yt] = getYbus(ps,false);
    ps = update_load_freq_source(ps);       % Set bus freq source (nearest gen)
    
    % Machine variables
    [ps.mac, ps.exc, ps.gov] = get_mac_state(ps, 'salient');
    
    % Initialize relays
    ps.relay = get_relays(ps, 'all', opt);
end


% Initialize global variables
global t_delay t_prev_check dist2threshold state_a;
n                       = size(ps.bus, 1);
ng                      = size(ps.mac, 1);
m                       = size(ps.branch, 1);
n_sh                    = size(ps.shunt, 1);
ix                      = get_indices(n, ng, m, n_sh, opt);
t_delay                 = inf(size(ps.relay, 1), 1);
t_delay([ix.re.uvls])   = opt.sim.uvls_tdelay_ini;
t_delay([ix.re.ufls])   = opt.sim.ufls_tdelay_ini;
t_delay([ix.re.dist])   = opt.sim.dist_tdelay_ini;
t_delay([ix.re.temp])   = opt.sim.temp_tdelay_ini;
t_prev_check            = nan(size(ps.relay, 1), 1);
dist2threshold          = inf(size(ix.re.oc, 2)*2, 1);
state_a                 = zeros(size(ix.re.oc, 2)*2, 1);

%% Build an event matrix
event = zeros(2, C.ev.cols);
% start
event(2,[C.ev.time C.ev.type]) = [0 C.ev.start];

% trip a branch
% event(2,[C.ev.time C.ev.type]) = [3 C.ev.trip_branch];
% event(2,C.ev.branch_loc) = 1;

% set the end time
event(2,[C.ev.time C.ev.type]) = [t_max C.ev.finish];


%% run the simulation
[outputs,ps,x,y] = simgrid(ps,event,'sim_rts96',opt,x_in,y_in);

save_sim_state(ps,x,y);

%% print the results
fname = outputs.outfilename;
[t,delta,omega,Pm,Eap,Vmag,theta,E1,Efd,P3,Temperature] = read_outfile(fname,ps,opt);
omega_0 = 2*pi*ps.frequency;
omega_pu = omega / omega_0;

figure(1); clf; hold on; 
nl = size(omega_pu,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xtick',[0 600 1200 1800],...
%     'Xlim',[0 50],'Ylim',[0.995 1.008]);
plot(t,omega_pu);
ylabel('\omega (pu)','FontSize',18);
xlabel('time (sec.)','FontSize',18);
% PrintStr = sprintf('OmegaPu_P_%s_%s_%s',CaseName, Contingency, Control);
% print('-dpng','-r600',PrintStr)

figure(2); clf; hold on; 
nl = size(theta,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[-0.2 0.5]);
plot(t,theta);
ylabel('\theta','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(3); clf; hold on; 
nl = size(Vmag,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Vmag);
ylabel('|V|','FontSize',18);
xlabel('time (sec.)','FontSize',18);

%{
figure(5); clf; hold on; 
nl = size(Pm,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Pm);
ylabel('Pm','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(6); clf; hold on; 
nl = size(delta,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
% plot(t',delta'.*180./pi);
plot(t,delta);
ylabel('Delta','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(7); clf; hold on; 
nl = size(Eap,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Eap);
ylabel('Eap','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(8); clf; hold on; 
nl = size(E1,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,E1);
ylabel('E1','FontSize',18);
xlabel('time (sec.)','FontSize',18);

figure(9); clf; hold on; 
nl = size(Efd,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Efd);
ylabel('Efd','FontSize',18);
xlabel('time (sec.)','FontSize',18);    

figure(10); clf; hold on; 
nl = size(Temperature,2); colorset = varycolor(nl);
% set(gca,'ColorOrder',colorset,'FontSize',18,'Xlim',[0 50],'Ylim',[0.88 1.08]);
plot(t,Temperature);
ylabel('Temperature ( ^{\circ}C)','Interpreter','tex','FontSize',18);
xlabel('time (sec.)','FontSize',18);
%}



