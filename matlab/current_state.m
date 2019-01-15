function load = current_state(ps, C)
%current_state(ps, C) builds a load matrix that contains bus voltage, bus
%angle, loads (in active and reactive)
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
load.active = ps.shunt(:, C.sh.P)*ps.shunt(:, C.sh.factor);
load.reactive = ps.shunt(:,C.sh.Q)*ps.shunt(:, C.sh.factor);

end

