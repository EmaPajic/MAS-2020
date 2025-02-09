% acsobiro() - A.C.'s Robust second-order blind identification (SOBI) by joint 
%              diagonalization of the time-delayed covariance matrices. NOTE:
%              THIS CODE ASSUMES TEMPORALLY CORRELATED SIGNALS Thus, estimated 
%              time-delayed covariance matrices must be nonsingular for at least 
%              some time delays.
%
% Usage:  >>   [H] = acsobiro(X);
%         >> [H,S] = acsobiro(X,n,p);
% Inputs: 
%         X - data matrix of dimension [m,N] where
%                    m is the number of sensors
%                    N is the number of samples
%         n - number of sources {Default: n=m}
%         p - number of correlation matrices to be diagonalized {default: p=100}
%             For noisy data, use at least 100 time delays.
% Outputs:
%         H - matrix of dimension [m,n] an estimate of the *mixing* matrix
%         S - matrix of dimension [n,N] an estimate of the source activities
%             where  >> X [m,N] = H [m,n] * S [n,N]
%
% Authors: Implemented and improved by A. Cichocki on the basis of 
%          the classical SOBI algorithm of Belouchrani and publications of: 
%           A. Belouchrani et al., F. Cardoso et al.,
%           S. Choi, S. Cruces, S. Amari, and P. Georgiev
%
% Note: updated by Arnaud Delorme and Scott Makeig to process data epochs
%       (compute an average correlation matrix respecting epoch boundaries).

% REFERENCES:
%  A. Belouchrani, K. Abed-Meraim, J.-F. Cardoso, and E. Moulines, ``Second-order
%  blind separation of temporally correlated sources,'' in Proc. Int. Conf. on
%  Digital Sig. Proc., (Cyprus), pp. 346--351, 1993.
%
%  A. Belouchrani, and A. Cichocki, 
%  Robust whitening procedure in blind source separation context, 
%  Electronics Letters, Vol. 36, No. 24, 2000, pp. 2050-2053.
%  
%  A. Cichocki and S. Amari, 
%  Adaptive Blind Signal and Image Processing, Wiley,  2003.

function [H,S,D]=acsorbiro(X,n,p),

[m,N,ntrials]=size(X);
if nargin<1 | nargin > 3
  help sobi
elseif nargin==1,
 n=m; % source detection (hum...)
 p=min(100,ceil(N/3)); % number of time delayed correlation matrices to be diagonalized 
                 % Note: For noisy data, use at least p=100 the time-delayed covariance matrices.
elseif nargin==2,
 p=min(100,ceil(N/3)); % number of correlation matrices to be diagonalized
end; 

X(:,:)=X(:,:)-(mean(X(:,:)')'*ones(1,N*ntrials));        % Remove data means 

for t = 1:ntrials 
    if t == 1
        Rxx=(X(:,1:N-1,t)*X(:,2:N,t)')/(N-1)/ntrials; % Estimate the sample covariance matrix 
                                          % for the time delay p=1, to reduce influence 
                                          % of white noise.
    else
        Rxx=Rxx+(X(:,1:N-1,t)*X(:,2:N,t)')/(N-1)/ntrials; % Estimate the sample covariance matrix 
                                          % for the time delay p=1, to reduce influence 
                                          % of white noise.
    end;
end;

[Ux,Dx,Vx]=svd(Rxx);
Dx=diag(Dx);
% n=11;
 if n<m, % under assumption of additive white noise and when the number 
         % of sources is known, or can be estimated a priori 
  Dx=Dx-real((mean(Dx(n+1:m))));
  Q= diag(real(sqrt(1./Dx(1:n))))*Ux(:,1:n)';
else    % under assumption of no additive noise and when the 
        % number of sources is unknown
   n=max(find(Dx>1e-99)); % detect the number of sources
   fprintf('acsobiro(): Estimated number of sources is %d\n',n);
   Q= diag(real(sqrt(1./Dx(1:n))))*Ux(:,1:n)';
end;
Xb = zeros(n,size(X,2));
%keyboard
Xb(:,:)=Q*X(:,:); % prewhitened data

m=n;
% Estimate the time delayed covariance matrices:
 k=1;
 pn=p*n; % for convenience
 for u=1:m:pn, 
   k=k+1; 
   for t = 1:ntrials 
       if t == 1
           Rxp=Xb(:,k:N,t)*Xb(:,1:N-k+1,t)'/(N-k+1)/ntrials;
       else
           Rxp=Rxp+Xb(:,k:N,t)*Xb(:,1:N-k+1,t)'/(N-k+1)/ntrials;
       end;
   end;
   %keyboard
   M(:,u:u+m-1)=norm(Rxp,'fro')*Rxp;  % Frobenius norm =
 end;                                  % sqrt(sum(diag(Rxp'*Rxp)))

% Approximate joint diagonalization:
eps=1/sqrt(N)/100; encore=1; U=eye(n);
while encore, encore=0;
 for p=1:n-1,
  for q=p+1:n,
    % Givens rotations:
    g=[ M(p,p:n:pn)-M(q,q:n:pn)  ;
        M(p,q:n:pn)+M(q,p:n:pn)  ;
        i*(M(q,p:n:pn)-M(p,q:n:pn))];
   [Ucp,D] = eig(real(g*g')); [la,K]=sort(diag(D));
   angles=Ucp(:,K(3));angles=sign(angles(1))*angles;
   c=sqrt(0.5+angles(1)/2);
   sr=0.5*(angles(2)-j*angles(3))/c; sc=conj(sr);
   asr = abs(sr)>eps ;
   encore=encore | asr ;
   if asr , % Update the M and U matrices: 
     colp=M(:,p:n:pn);
     colq=M(:,q:n:pn);
     M(:,p:n:pn)=c*colp+sr*colq;
     M(:,q:n:pn)=c*colq-sc*colp;
     rowp=M(p,:);
     rowq=M(q,:);
     M(p,:)=c*rowp+sc*rowq;
     M(q,:)=c*rowq-sr*rowp;
     temp=U(:,p);
     U(:,p)=c*U(:,p)+sr*U(:,q);
     U(:,q)=c*U(:,q)-sc*temp;
   end  %% if
  end  %% q loop
 end  %% p loop
end  %% while

% Estimate the mixing matrix H 
H= pinv(Q)*U(1:n,1:n); 

% Estimate the source activities S
if nargout>1
  S=[];
  W=U(1:n,1:n)'*Q; 
  S= W*X(:,:);
end

