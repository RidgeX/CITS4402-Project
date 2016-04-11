classdef LRC
    properties (Constant)
        % Parameters:
        kSubsampleSize = [10 5];
        numTrain = 5;
    end
    properties
        % Stores the training images in columnised format. This is the
        % matrix X_i described in the paper.
        training;
        % Stores the testing images.
        test;
        % Cached the values of the matrix H_i described in the paper.
        hats;
        % Names of the classes (subjects).
        classes;
    end
    methods
        function obj = LRC(imgLoc)
            [obj.training, obj.test, obj.classes] = obj.readImages(imgLoc);
            obj.hats = obj.computeHatMatrices();
        end
        
        function [accuracy] = computeAccuracy(obj)
            accuracy = 0.0;
            for class = 1 : length(obj.classes)
                for i = 1 : obj.numTrain
                    predicted = obj.lrc(obj.test(:,i,class));
                    if predicted == class
                        accuracy = accuracy + 1.0;
                    end
                end
            end
            
            accuracy = accuracy / (obj.numTrain * length(obj.classes));
        end
        
        function [class] = lrc(obj, img)
            % For each class, compute the projection into its subspace and
            % get the one with the smallest eucliean distance to the input
            % image.
            dists = zeros(length(obj.classes), 1);
            for i = 1 : length(dists)
                dists(i) = sum((img - obj.hats(:,:,i) * img) .^ 2);
            end
            % Return the index of the minimum distance.
            [minDist, class] = min(dists);
        end
        
        function [img] = preprocessImage(obj, img)
            % Resize image to the subsample size (defined as 10x5 in
            % the paper.
            img = imresize(img, obj.kSubsampleSize);
            % Columnise and convert to doubles.
            colLen = prod(obj.kSubsampleSize);
            img = double(reshape(img, colLen, 1));
            % Noramlise so the maximum component is 1.
            img = img / max(img);
        end
        function [hats] = computeHatMatrices(obj)
            % Compute H_i = X_i * (tranpose(X_i) * X_i) ^-1 *
            % transpose(X_i)
            imageLen = prod(obj.kSubsampleSize);
            numClasses = length(obj.classes);
            hats = zeros(imageLen, imageLen, numClasses);
            for i = 1 : numClasses
                Xi = obj.training(:,:,i);
                hats(:,:,i) = Xi / (Xi' * Xi) * Xi';
            end
        end
        function [training, test, classes] = readImages(obj, location)
            % Each directory in the image directory is a subject (class).
            classes = dir(strcat(location, '/s*'));
            classes = {classes.name};
            % For each training class, stores training images. Preallocate space.
            colLen = prod(obj.kSubsampleSize);
            % Store each image as a column.
            training = zeros(colLen, obj.numTrain, length(classes));
            
            % imageOrder = 1:obj.numTrain*2;
            imageOrder = randperm(obj.numTrain*2);
            
            for class = 1 : length(classes)
                for i = 1 : obj.numTrain * 2
                    filename = sprintf('%s/%s/%d.pgm', location, classes{class}, imageOrder(i));
                    % Read in and preprocess the image.
                    img = obj.preprocessImage(imread(filename));
                    if i <= obj.numTrain
                        training(:, i, class) = img;
                    else
                        test(:, i - obj.numTrain, class) = img;
                    end
                end
            end
        end
    end
end
