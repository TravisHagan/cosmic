function [reward, count] = get_load_reward(initial_load, load, reward, count, k)
% Returns the reward ratio for a change in load
% 
% 
%

ratio = [0,0];
ratio(1) = load.active(k)/initial_load.active(k);
ratio(2) = load.reactive(k)/initial_load.reactive(k);

if ratio(1) == Inf
    ratio(1) = 0;
end

if ratio(2) == Inf
    ratio(2) = 0;
end


reward = reward + ratio(1) + ratio(2);
count = count + 1;

end

