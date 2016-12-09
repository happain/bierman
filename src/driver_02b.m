%
% Copyright 2016 Kurt Motekew
%
% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this
% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%

% This driver script does speed comparisions with the U-D and SRIF
% estimation methods.  Containment is also output


close all;
clear;

SF95_3D = 2.796;
k2_3d = SF95_3D*SF95_3D;

  % INPUTS
ntest = 20;
  % True location of object to be located
rho = [0.25 0.25 0]';
  % Tracker locations
blen = 1;
tkrs = [
         0       0       blen ;
         blen    0       blen ;
         blen    blen    blen ;
         0       blen    blen
      ]';
nmeas = size(tkrs,2);                        % Batch init
nmeas2 = 100;                                % Sequential obs, static

  % Tracker accuracy
srng = .05;
vrng = srng*srng;
W = 1/vrng;
Wsqrt = 1/srng;
y(nmeas) = 0;
y2(nmeas2) = 0;
testnum = 1:ntest;
miss_ud = zeros(1,ntest);
miss_srif = zeros(1,ntest);
contained_3d_ud = 0;
contained_3d_srif = 0;
ud_time = 0;
srif_time = 0;

%
% Loop over the number of trials
%

for jj = 1:ntest
    % Create synthetic measurements using error budget
  for ii = 1:nmeas
    s = rho - tkrs(:,ii);
    yerr = srng*randn;
    y(ii) = norm(s) + yerr;
  end
    % Additional observations
  for ii = 1:nmeas2
      % Determine which tracker to get the obs from
    itkr = mod(ii,nmeas);
    if itkr == 0
      itkr = nmeas;
    end
    s = rho - tkrs(:,itkr);
    yerr = srng*randn;
    y2(ii) = norm(s) + yerr;
  end
    % Estimate location using initial set of obs
  [phat0, SigmaP0, ~] = box_locate(tkrs, y, W);

    % Sequential estimation based on initial estimate
  phat_ud = phat0;
  [U, D] = mth_udut2(SigmaP0);                   % U-D, SigmaP = UDU'
    % Use Householder method for initial estimate and get info array
  [phat_srif, SigmaP_srif, R, z, ~] = box_locate_hh(tkrs, y, Wsqrt*eye(nmeas));

  %
  % Updates
  %

    % U-D
  tic;
  for ii = 1:nmeas2
    itkr = mod(ii,nmeas);
    if itkr == 0
      itkr = nmeas;
    end
    Ap = est_drng_dloc(tkrs(:,itkr), phat_ud);
    yc = norm(phat_ud - tkrs(:,itkr));
    r = y2(ii) - yc;
    [phat_ud, U, D] = est_upd_ud(phat_ud, U, D, Ap, r, vrng);
  end
  ud_time = ud_time + toc;

    % SRIF
  tic;
  for ii = 1:nmeas2
    itkr = mod(ii,nmeas);
    if itkr == 0
      itkr = nmeas;
    end
    Ap = est_drng_dloc(tkrs(:,itkr), phat_srif);
    yc = norm(phat_srif - tkrs(:,itkr));
    r = y2(ii) - yc;
    [dp, R, z] = est_upd_hhsrif(R, z*srng, Ap, r, Wsqrt);
    phat_srif = phat_srif + dp;
  end
  srif_time = srif_time + toc;

  %
  % End updates
  %

    % Get containment stats for each
  miss_ud(jj) = norm(phat_ud - rho);
  if (SF95_3D > mth_mahalanobis(rho, phat_ud, U*D*U'))
    contained_3d_ud = contained_3d_ud + 1;
  end
  miss_srif(jj) = norm(phat_srif - rho);
  Rinv = mth_triinv(R);
  if (SF95_3D > mth_mahalanobis(rho, phat_srif, Rinv*Rinv'))
    contained_3d_srif = contained_3d_srif + 1;
  end
end
p95_3d_ud = 100*contained_3d_ud/ntest;
p95_3d_srif = 100*contained_3d_srif/ntest;

figure; hold on;
plot(testnum, miss_ud, 'o', testnum, miss_srif, '+');
xlabel('Trial');
ylabel('RSS Miss Distance');
legend('U-D', 'SRIF');

fprintf('\nU-D containment: %1.1f', p95_3d_ud);
fprintf(' in %1.4f seconds', ud_time);
fprintf('\nSRIF containment: %1.1f', p95_3d_srif);
fprintf(' in %1.4f seconds', srif_time);

fprintf('\n');


