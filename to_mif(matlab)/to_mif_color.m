take = imread('NEXT_TXT.bmp');
img = im2bw(take);
imshow(img);

[V, H, D] = size(img);
fid = fopen('next.mif','w');


fprintf(fid,'WIDTH=1;\n');
fprintf(fid,'DEPTH=%d;\n\n',V*H);
fprintf(fid,"ADDRESS_RADIX=UNS;\n");
fprintf(fid,"DATA_RADIX=HEX;\n\n");
fprintf(fid,'CONTENT BEGIN\n');
%img(i, j, 1) : R;
%img(i, j, 2) : G;
%img(i, j, 3) : B;

for i = 1:1:V
    for j = 1:1:H
        fprintf(fid,'\t%d\t:\t',(i-1) *H + (j-1));
        fprintf(fid, "%d", img(i,j,1));
        %fprintf(fid, "%02X%02X%02X", img(i,j,1), img(i,j,2), img(i,j,3));
        fprintf(fid,';\n');
    end
end

fprintf(fid,'END;\n');
fclose(fid);
