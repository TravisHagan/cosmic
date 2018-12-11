function [save_status] = save_sim_state(ps,x,y,filename)
% usage: [save_status] = save_sim_state(filename)
% Save the simulation state to resume from. It saves the PS struct to
% preserve all phasors, loads, etc...
% 

save_status = 0;

if nargin < 4
    filename = 'save_state';
end

save(strcat(filename, '.mat'), 'ps', 'x', 'y')







