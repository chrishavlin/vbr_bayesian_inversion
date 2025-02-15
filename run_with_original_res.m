% should exactly reproduce run_invert_xfit_premelt.m, with the caveat that the results
% end up in results/state_variables_xfit_premelt/
addpath('./functions')
addpath('./inv_functions')
addpath('./GLAD25')

% load in the observations, limited by spatial extent
spatial_sampling.elim = -10.;     % eastern limit [decimal degrees; multiple of 0.5]
spatial_sampling.wlim = -80.;     % western limit [decimal degrees; multiple of 0.5]
spatial_sampling.nlim = 86.;      % nothern limit [decimal degrees; multiple of 0.5]
spatial_sampling.slim = 56.;      % southern limit [decimal degrees; multiple of 0.5]
spatial_sampling.xy_res = 2;  % spatial resolution [decimal degrees; multiple of 0.5]
spatial_sampling.z_start_index = 4; % index of the top depth [between 1 and 40].
spatial_sampling.z_end_index = 40;  % index of the bottom depth [between 1 and 40].
spatial_sampling.z_res = 1;         % depth sampling factor [each depth slice is 10 km].
observations = load_data(spatial_sampling);

% load in the vbr predictions for selected method
qmethod = 'xfit_premelt';     % Choose from xfit_premelt, xfit_mxw, eburgers_psp, andrade_psp
vbr_predictions = load_vbr_box('sweep_box.mat', qmethod, observations);

% run the inversion
% set the starting models for melt fraction and grain size
bayesian_settings.phi0 = 0.01; % melt fraction
bayesian_settings.g0 = log10(1000.); % 1 mm (1000 microns)
bayesian_settings.std_T = 50.; % degree C
bayesian_settings.std_phi = 0.0025; % melt fraction
bayesian_settings.std_g = 0.2; % grain size in log units
bayesian_settings.lscale = 200.; % distance scale, km

results = bayesian_inversion(bayesian_settings, observations, vbr_predictions);

% Extract covariances for chosen sites
lat_site1 = 78;
lon_site1 = -42;
Vpo_site1 = extract_site_covariance(results, observations, lat_site1, lon_site1, 1);

lat_site2 = 68;
lon_site2 = -34;
Vpo_site2 = extract_site_covariance(results, observations, lat_site2, lon_site2, 1);

lat_site3 = 66;
lon_site3 = -48;
Vpo_site3 = extract_site_covariance(results, observations, lat_site3, lon_site3, 1);

% save some output
output_dir = './results/state_variables_xfit_premelt';
save_bayes_results(output_dir, observations, results)
save([output_dir, '/Vpo_site1.mat'], 'Vpo_site1')
save([output_dir, '/Vpo_site2.mat'], 'Vpo_site2')
save([output_dir, '/Vpo_site3.mat'], 'Vpo_site3')