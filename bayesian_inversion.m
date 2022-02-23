%% RUN A BAYESIAN INVERSION  
%
%  Here we will solve for the best T, phi, g for a given 
%  tomography model using non-linear Bayesian inference


function results = bayesian_inversion(bayesian_settings, observations, vbr_predictions)
    
    addpath('./functions')
    addpath('./inv_functions')

    % extract variables from observations structure
    vs = observations.vs;
    Q = observations.Q;
    lons = observations.lons;
    lats = observations.lats;
    zs = observations.zs;
    nlat = observations.nlat;
    nlon = observations.nlon;
    nz = observations.nz;
    npts = observations.npts;
    vs_err = observations.vs_err;
    Q_err = observations.Q_err;
    vs_vbr = vbr_predictions.vs_vbr;
    Q_vbr = vbr_predictions.Q_vbr;
    phi = vbr_predictions.phi;
    g = vbr_predictions.g;
    T = vbr_predictions.T;
    nT = length(T);
    ng = length(g);
    nphi = length(phi);
    
    
    % calculate log10(Q) quantities
    
    lQ = log10(Q);
    lQ_err = log10(Q_err);
    lQ_vbr= log10(Q_vbr);

    %% BEGIN MAKING INITIAL VECTORS AND MATRICES

    %  For all spatial dimensions, the loop order is same as tomography:
    %      for ilat=1:nlat ... Latitude
    %         for ilon=1:nlon ... Longitude
    %            for iz=1:nz ... Depth
    %  The order for the model parameters is T1, phi1, g1, T2, phi2, g2, ...
    %  Our total model space is (npts * number of physical parameters):
    pars = {'T'; 'phi'; 'g'};    % set the free thermodynamic parameters in the inversion
    npar = numel(pars); 
    nmod = npts*npar;
    ntype = 2; % number of observational datasets (Vs and Q)
    ndata = npts*ntype; % total data

    %  (1) Starting (X0) and Prior (Xpr) Models
    %  Let's assume X0 and Xpr are the same.
    phi0 = bayesian_settings.phi0; % melt fraction
    g0 = bayesian_settings.g0; % grain size (in microns)

    % TO DO: switch following function to just make_X0
    [X0,iT,iphi,ig] = make_X0(vs,nz,nlat,nlon,nmod,npts,vs_vbr,phi0,g0,phi,g,T);
    Xpr = X0;

    %  (2) Frechet kernel (F) of the starting model
    F = make_F(vs_vbr,lQ_vbr,nlat,nlon,nz,ndata,nmod,T,phi,g,iT,iphi,ig,nT,nphi,ng);

    %  (3) Make Covariance Matrices
    %      Data covariance matrix (Vd):
    Vd = make_Vd(ndata,nlat,nlon,nz,lQ_err,vs_err);

    %      Model covariance matrix (Vm):
    std_T = ones(npts)*bayesian_settings.std_T;
    std_phi = ones(npts)*bayesian_settings.std_phi;
    std_g = ones(npts)*bayesian_settings.std_g; % log units
    lscale = bayesian_settings.lscale; % km
    Vm = make_Vm(std_T,std_phi,std_g,lscale,lats,lons,zs,npts,nmod);

    %  (4) Residual (y - f(X))
    yres = calc_yres(ndata,nlat,nlon,nz,iT,iphi,ig,vs_vbr,lQ_vbr,vs,lQ);

    %% BEGIN INVERSION

    %  Only Xk, F, and yres are updated in this scheme...

    irun = 1;
    % invert some matrices:
    Vdi = Vd\eye(ndata);
    Vmi = Vm\eye(nmod);
    Xk = X0;

    iter=1;

    iphi_idx = (2:3:nmod);
    iT_idx = (1:3:nmod);
    ig_idx = (3:3:nmod);

    while irun == 1
        
        % form inversion

        mat1 = F'*Vdi*F;
        mat2 = Vmi;
        matA = mat1+mat2;
        matA = matA\eye(nmod);
        
        mat1 = F'*Vdi*yres;
        mat2 = Vmi*(Xk-Xpr);
        matB = mat1-mat2;
        
        Xk1 = Xk + matA*matB;
        
        iphi0s = find(Xk1(iphi_idx)<0); % can't have negative melt
        Xk1(iphi_idx(iphi0s))=0.;

        % calculate misfit    
        [iTs,iphis,igs] = find_idx(Xk1,npts,nlat,nlon,nz,phi,g,T);
        yres = calc_yres(ndata,nlat,nlon,nz,iTs,iphis,igs,vs_vbr,lQ_vbr,vs,lQ);
        chi2 = yres'*Vdi*yres/ndata;
        display(['Chi-Squared ',num2str(chi2),' for iteration ',num2str(iter)])

        max_iter = 1;
        chi_limit = 1;
        if ((chi2 > chi_limit)&&(iter<max_iter))
            irun=1;
            
            % update F
            F = make_F(vs_vbr,lQ_vbr,nlat,nlon,nz,ndata,nmod,...
                T,phi,g,iTs,iphis,igs,nT,nphi,ng);

            % update model Xk
            Xk = Xk1;
            iter=iter+1;
        else 
            irun=0;
            if (iter>=max_iter)
                disp(['Did not converge after ' num2str(iter) ' iterations']);
            else
                disp(['Converged to chi-squared < ' num2str(chi_limit) ' after ' num2str(iter) ' iterations']);
            end
        end
    end

    %% EXTRACT OUTPUT
    % TO DO: decide what in the following should be in the repository
    % Calculate the posterior distribution.
    mat1 = F'*Vdi*F;
    mat2 = Vmi;
    matA = mat1+mat2;
    Vpo = matA\eye(nmod);
    Vpo_var = diag(Vpo);

    results.Vpo = Vpo;
    results.Vpo_var = Vpo_var;
    results.npar = npar;

    % Extract maximum likelihood state variables as functions of lat, lon, z
    Xk1_temp = Xk1(iT_idx);
    Xk1_phi = Xk1(iphi_idx);
    Xk1_g = Xk1(ig_idx);

    Xk1_temp = permute(reshape(Xk1_temp,[nz,nlon,nlat]),[3 2 1]);
    Xk1_phi = permute(reshape(Xk1_phi,[nz,nlon,nlat]),[3 2 1]);
    Xk1_g = permute(reshape(Xk1_g,[nz,nlon,nlat]),[3 2 1]);

    results.Xk1_temp =  Xk1_temp;
    results.Xk1_phi =  Xk1_phi;
    results.Xk1_g =  Xk1_g;

    % also save some output
    output_dir = bayesian_settings.output_dir;
    if ~exist(output_dir,'dir')
        mkdir(output_dir);
    end
    save_max_likelihood(output_dir, lats, lons, zs, results)

    vpofile = [output_dir, '/Vpo.mat'];
    disp(["saving Vpo_var to ", vpofile])
    save(vpofile,'Vpo_var');

    fullresults = [output_dir, '/bayes_results.mat'];
    disp(["saving full bayesian inversion results to ", fullresults])
    save(fullresults, '-struct', 'results')
  
end


function save_max_likelihood(output_dir, lats, lons, depth, results)

    fields_to_save = {'Xk1_temp'; 'Xk1_phi'; 'Xk1_g'};

    % build a struct with field aliases for each field
    % each one is {'fieldname'; 'structure_name'};
    save_info.Xk1_temp = {'temperature'; 'Temp'};
    save_info.Xk1_phi = {'meltfraction'; 'Phi'};
    save_info.Xk1_g = {'grainsize'; 'GrainSize'};

    for ifield = 1:numel(fields_to_save)
        field = fields_to_save{ifield};

        % (re)initialize the struct to save
        OuterStruct = struct();
        s_name = save_info.(field){2};
        OuterStruct.(s_name) = struct();
        OuterStruct.(s_name).latitude = lats;
        OuterStruct.(s_name).longitude = lons;
        OuterStruct.(s_name).depth = depth;

        % add the field to save
        fieldnametosave = save_info.(field){1};
        OuterStruct.(s_name).(fieldnametosave) = results.(field);

        filename = [output_dir, '/', s_name, '.mat'];
        disp(['Saving max likelihood of ', fieldnametosave, ' to ', filename])
        save(filename, '-struct', 'OuterStruct', s_name)
    end
end
