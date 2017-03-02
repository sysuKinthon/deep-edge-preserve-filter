function [inputs, labels, set] = patches_generation(size_input,size_label,stride,folder,mode,max_numPatches,batchSize)

%size_input = 200;
%size_label = 200;
%padding = abs(size_input- size_input) / 2;
%stride = 80;

%% get all the picture's path
ext          = {'*.jpg', '*.png', '*.bmp'};
filepaths    = [];
for i = 1: length(ext):
  filepaths = cat(1,filepaths, dir(fullfile(folder, ext(i))));
end

%% init all the data
count = 0;
inputs  = zeros(size_input, size_input, 1, 1,'single');
labels  = zeros(size_label, size_label, 1, 1,'single');

image = imread('test.jpg');
image_label = L0Smoothing(image);
if size(image, 3) == 3
  image = rgb2gray(image); %uint8
  image_label = rgb2gray(image_label); %uint8
end

%%augmentation data and Generate patches
for j = 1:8
    image_aug = data_augmentation(image, j);  % augment data
    image_label_aug  = data_augmentation(image_label, j);
    im_input = im2single(image_aug); % single
    im_label = im2single(image_label_aug);
    [hei,wid] = size(im_label);
    wid
    for x = 1 : stride : (hei-size_input+1)
        for y = 1 :stride : (wid-size_input+1)
            y+size_input-1
            subim_input = im_input(x : x+size_input-1, y : y+size_input-1);
            subim_label = im_label(x+padding : x+padding+size_label-1, y+padding : y+padding+size_label-1);
            count       = count+1;
            inputs(:, :, 1, count) = subim_input;
            labels(:, :, 1, count) = subim_label;
        end
    end
end

%%show some
%input_one = inputs(:,:,1,50);
%label_one = labels(:,:,1,50);
%imshow(cat(2, im2uint8(input_one), im2uint8(label_one)))

%% go on deal with the data according with the bachSize the inputs and the lables must tobe the multiple of the batchSiz and Generate the residual
inputs = inputs(:,:,:,1:(size(inputs,4)-mod(size(inputs,4),batchSize)));
labels = labels(:,:,:,1:(size(labels ,4)-mod(size(labels ,4),batchSize)));
labels = shave(inputs,[padding,padding])-labels; %%% residual image patches; pay attention to this!!!

%shuffle the data
order  = randperm(size(inputs,4));
inputs = inputs(:, :, 1, order);
labels = labels(:, :, 1, order);

% distinguish the train data and the test data
set    = uint8(ones(1,size(inputs,4)));
if mode == 1
    set = uint8(2*ones(1,size(inputs,4)));
end

%limitation the pathces num
disp('-------Original Datasize-------')
disp(size(inputs,4));

subNum = min(size(inputs,4),max_numPatches);
inputs = inputs(:,:,:,1:subNum);
labels = labels(:,:,:,1:subNum);
set    = set(1:subNum);

disp('-------Now Datasize-------')
disp(size(inputs,4));
