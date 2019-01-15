function results = Non_rollout_case(ps, opt, C, time, save_file, Rollout_file)
%results_file_screation provides a comparable base case to the rollout
%policy
%
% C.sh.status and C.sh.factor can be used to scale elements
%
% RTS96 is only setup to use constant power loads (P).
% Constant current loads (I) and constant impedance loads (Z) are not
% currently being used. To simplify this script, only (P) loads are used
% in the calculation.
%

global attack;

%% Store current operating point

% save ps and save_state
load_initial = current_state(ps, C);

% Do nothing case
results.LS0.bus = -99;
results.LS0.reward = -1;
results.LS0.status = 1;
results.LS0.Load_shedding_percent = 0;
results.LS0.demand_lost = 0;
results.case = Rollout_file;
    
% Reload case
[ps, x, y] = load_sim_state(save_file);
    
% Reset counters and variables
time.sim = 0;
    
    
time.multiplier = 1;
t_step = time.step;         % Load default time step
attack.t_cur = attack.t_start;
    
while time.sim <= time.max
    % Variable time step
    if time.sim < 5
        t_step = time.step;
    elseif time.sim >= 5 && time.sim < 10   % (5 <= time < 10)
        t_step = time.step1;
    elseif time.sim >= 10               % (10 < time)
        t_step = time.step2;
    end
    
    time.sim = time.sim + t_step;
        
    [outputs,ps,x,y] = rollout_continuation(ps, x, y, opt, C, t_step);
    
    attack.t_cur = attack.t_cur + outputs.t_simulated(end);
    results.LS0.demand_lost = results.LS0.demand_lost + outputs.demand_lost;
    
    if outputs.success == false
        results.LS0.status = 0;
        break;
    end
            
    load_current = current_state(ps, C);     
end
        
fprintf('\nDemand_lost %2.3f\n',results.LS0.demand_lost);
   

outfile = strcat('Results\',Rollout_file,'.mat');
save(outfile, 'results');

end



