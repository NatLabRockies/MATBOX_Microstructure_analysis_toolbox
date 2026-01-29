function [surface] = Function_Specificinterface_direct_Algorithm_noPos(M)
% M: 0 other phases, 1: phase A, 10: phase B

sz = size(M);
dimension = length(sz);

M = int8(M);

% Detection of the faces normal to the direction 1
Face_normal_1 = abs (M(1:sz(1)-1,:,:) - M(2:sz(1),:,:)); % Fail if uint8
Face_normal_1(Face_normal_1~=9)=0;
Face_normal_1(Face_normal_1==9)=1;
% Summation of all these faces
sum1 = sum(sum(sum( Face_normal_1 )));

% Detection of the faces normal to the direction 2
Face_normal_2 = abs( M(:,1:sz(2)-1,:) - M(:,2:sz(2),:));
Face_normal_2(Face_normal_2~=9)=0;
Face_normal_2(Face_normal_2==9)=1;
% Summation of all these faces
sum2 = sum(sum(sum( Face_normal_2 )));

if dimension == 3
    % Detection of the faces normal to the direction 3
    Face_normal_3 = abs( M(:,:,1:sz(3)-1) - M(:,:,2:sz(3)));
    Face_normal_3(Face_normal_3~=9)=0;
    Face_normal_3(Face_normal_3==9)=1;
    % Summation of all these faces
    sum3 = sum(sum(sum( Face_normal_3 )));
else
    sum3 = 0;
end

% Summation of all the faces
surface=sum1+sum2+sum3;

end