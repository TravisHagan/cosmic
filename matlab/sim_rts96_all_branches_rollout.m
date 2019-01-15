%% Rollout policy simulation file
clear all; close all; clc;

time.contingency = 5;       % When the contingency should occur
time.rollout = 10;          % Time when rollout policy starts
time.max = 25;              % Maximum rollout sim time
time.step = 1/30;           % Time step for rollout policy
time.step1 = 1/5;           % Time step for rollout policy (after 5 sec)
time.step2 = 1;             % Time step for rollout policy (after 10 sec)

if ~(ismcc || isdeployed)
    addpath('../data');
    addpath('../numerics');
end

C = psconstants;
opt = psoptions;
input_file = 'rts96_S.mat';

load(input_file,'ps');

%********** Features in Progress *************
opt.sim.use_data_correction = false;
opt.sim.attack_data = false;
opt.sim.use_rollout_policy = false;
opt.sim.use_relays = 'none';            % See get_relays or use 'none' or 'all'
%*********************************************

%% Output file:
results = cell(length(ps.branch(:,1)),4);         % Allocate cell matrix for results files

output_file = sprintf('sim_rts96_%s', datestr(now,'yyyy-mm-dd_HHMMSS'));

output.begin_time = datestr(now);
output.t_max = time.max;
output.data_correction = opt.sim.use_data_correction;
output.attacked_data = opt.sim.attack_data;
output.use_rollout_policy = opt.sim.use_rollout_policy;
output.use_relays = opt.sim.use_relays;



%%
for k = 1:length(ps.branch(:,1))
%for k = 1:3                                    % For testing
    
    % Store case details
    from_bus = ps.branch(k, C.br.from);
    to_bus = ps.branch(k, C.br.to);
    results{k,1} = from_bus;
    results{k,2} = to_bus;
    results{k,3} = ps.branch(k, C.br.id);
    
    % Reload case
    load(input_file,'ps')
    
    % Temporary file in-case of program crash, etc...
    Rollout_file = strcat('Branch_trip_',num2str(from_bus),'_',num2str(to_bus));
    
    fprintf('****************************************\n')
    fprintf('       New simulation beginning         \n')
    fprintf('       Line to trip: %d to %d           \n',ps.branch(k,1),ps.branch(k,2))
    fprintf('****************************************\n')
    
    % to differentiate the line MVA ratings
    rateB_rateA = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
    rateC_rateA = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
    ps.branch(rateB_rateA == 1,C.br.rateB) = 1.1*ps.branch(rateB_rateA == 1,C.br.rateA);
    ps.branch(rateC_rateA == 1,C.br.rateC) = 1.5*ps.branch(rateC_rateA == 1,C.br.rateA);
    
    % Reset options
    opt.sim.integration_scheme      = 1;
    opt.sim.dt_default              = 1/10;
    opt.nr.use_fsolve               = true;
    opt.verbose                     = false;
    opt.sim.gen_control = 1;        % 0 = generator without exciter and governor, 1 = generator with exciter and governor
    opt.sim.angle_ref = 0;          % 0 = delta_sys, 1 = center of inertia---delta_coi
                                    % Center of inertia doesn't work when having islanding
    opt.sim.COI_weight = 0;         % 1 = machine inertia, 0 = machine MVA base(Powerworld)
    opt.sim.uvls_tdelay_ini = 0.5;  % 1 sec delay for uvls relay.
    opt.sim.ufls_tdelay_ini = 0.5;  % 1 sec delay for ufls relay.
    opt.sim.dist_tdelay_ini = 0.5;  % 1 sec delay for dist relay.
    opt.sim.temp_tdelay_ini = 1e6;    % 0 sec delay for temp relay.
    opt.sim.writelog = false;
    % Don't forget to change this value (opt.sim.time_delay_ini) in solve_dae.m
    
    % Reset devices:
    % ps = unify_generators(ps);
    % ps.branch(:,C.br.tap)       = 1;
    % ps.shunt(:,C.sh.factor)     = 1;    % C.sh.factor is the same as C.sh.status
    ps.shunt(:,C.sh.status)     = 1;
    ps.shunt(:,C.sh.frac_S)     = 1;
    ps.shunt(:,C.sh.frac_E)     = 0;
    ps.shunt(:,C.sh.frac_Z)     = 0;
    ps.shunt(:,C.sh.gamma)      = 0.08;
    
    %% Initialize the case
    [ps, ~, ~] = newpf(ps,opt);
    
    [ps.Ybus, ps.Yf, ps.Yt] = getYbus(ps,false);
    ps = update_load_freq_source(ps);       % Set bus freq source (nearest gen)
    
    % Machine variables
    [ps.mac, ps.exc, ps.gov] = get_mac_state(ps, 'salient');
    
    % Initialize relays
    ps.relay = get_relays(ps, opt.sim.use_relays, opt);
    
    % Initialize global variables
    global t_delay t_prev_check dist2threshold state_a attack;
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
    attack.bus              = 101;                  % GPS Spoofing bus/buses
    attack.t_start          = 5;                    % When Spoofing attack starts
    attack.t_end            = time.max;             % End of Spoofing attack
    attack.t_cur            = 0;                    % Stored variable for attack module
    attack.flag             = true;                 % 
    attack.values_i         = [];                   % Initial variables
    attack.values           = [];                   % Current variables
    
    
    %% Build an event matrix
    event = zeros(3, C.ev.cols);
    
    % start
    event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];
    
    % trip a branch
    event(2,[C.ev.time C.ev.type]) = [time.contingency C.ev.trip_branch];
    event(2, C.ev.branch_loc) = ps.branch(k, C.br.id);
    
    % set the end time
    event(3,[C.ev.time C.ev.type]) = [time.rollout C.ev.finish];


    %% run the simulation
    [~,ps,x,y] = simgrid(ps,event,'sim_rts96',opt);
    
    save_sim_state(ps,x,y,'save_state');

    % results
    if opt.sim.use_rollout_policy
        results{k,4} = RolloutPolicy(ps, opt, C, time, 'save_state', Rollout_file);
    else
        results{k,4} = Non_rollout_case(ps, opt, c, time, 'save_state', Rollout_file);
    end
    
    %
    %
    %
    %
    % Implement later
    % Get highest reward and shed load, continue simulation
    %
    %
    %
    %       
end

output.end_time = datestr(now);
output.calculations = results;

save(output_file,'output');




