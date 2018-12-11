function [ps, x, y] = load_sim_state(filename)
% usage: [ps, x, y] = load_sim_state(filename)
% Loads simulation variables from another simulation
%

if nargin < 1
    filename = 'save_state';
end

load(strcat(filename, '.mat'))