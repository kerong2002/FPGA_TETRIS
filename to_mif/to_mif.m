clear;
clc;
n=6900;
mat = imread('LOGO.bmp');
mat = double(mat);
fid = fopen('bmp_data.mif','w');
fprintf(fid,'WIDTH=24;\n');
fprintf(fid,'DEPTH=6900;\n');
fprintf(fid,"ADDRESS_RADIX=UNS;\n");
fprintf(fid,"DATA_RADIX=HEX;");
fprintf(fid,'CONTENT BEGIN\n');
for i = 0:n-1
    x = mod(i,100)+1;
    y = fix(i/100)+1;
    k = mat(y,x);
fprintf(fid,'\t%d:%x;\n',i,k);
end
fprintf(fid,'END;\n');
fclose(fid);
