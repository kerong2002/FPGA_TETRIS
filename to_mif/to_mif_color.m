img = imread('LOGO.bmp');
imshow(img);

[V, H, D] = size(img);
fid = fopen('img.mif','w');


fprintf(fid,'WIDTH=24;\n');
fprintf(fid,'DEPTH=6900;\n');
fprintf(fid,"ADDRESS_RADIX=UNS;\n");
fprintf(fid,"DATA_RADIX=HEX;\n");
fprintf(fid,'CONTENT BEGIN\n');
%img(i, j, 1) : R;
%img(i, j, 2) : G;
%img(i, j, 3) : B;

for i = 1:1:V
    for j = 1:1:H
        fprintf(fid,'\t%d:',(i-1) *H + (j-1));
        fprintf(fid, "%02X%02X%02X", img(i,j,1), img(i,j,2), img(i,j,3));
        fprintf(fid,';\n');
    end
    fprintf(fid,'\n');
end

fprintf(fid,'END;\n');
fclose(fid);
