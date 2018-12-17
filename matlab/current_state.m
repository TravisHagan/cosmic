function load = current_state(ps, C)
% Returns the current state of loads, and voltages.
% 
% State variables:
% bus_nums = ps.shunt(:, C.sh.bus)
% Filter: temp = find((ismember(ps.bus(:,1), ps.shunt(:,1))~=0))
% voltages = ps.bus(temp, C.bus.Vmag)
% voltage_angle = ps.bus(temp, C.bus.Vang)
% load_nums = 
% load_ids = ps.shunt(:, C.sh.id)
% c_pow = ps.shunt(:, C.sh.P) + j*ps.shunt(:, C.sh.Q)
% c_cur = NOT USED
% c_imp = NOT USED

load.b = ps.shunt(:, C.sh.bus);
t = ismember(ps.bus(:,1), ps.shunt(:,1));
has_load = find(t~=0);
no_load = find(t==0);
load.v = ps.bus(has_load, C.bus.Vmag);
load.va = ps.bus(has_load, C.bus.Vang);
load.id = ps.shunt(:, C.sh.id);
load.active = ps.shunt(:, C.sh.P);
load.reactive = ps.shunt(:,C.sh.Q);

end

