function [outputs, ps, x, y] = rollout_continuation(ps, x_in, y_in, opt, C, time_step)
% Rollout continuation

t_max = time_step;         % Simulation time

%% Build an event matrix
event = zeros(3, C.ev.cols);
% start
event(2,[C.ev.time C.ev.type]) = [0 C.ev.start];
% set the end time
event(2,[C.ev.time C.ev.type]) = [t_max C.ev.finish];


%% run the simulation
[outputs,ps,x,y] = simgrid(ps,event,'sim_rts96',opt,x_in,y_in);