classdef LRC
    properties (Constant)
        % Parameters:
        SUBSAMPLE_SIZE = [10 5];
        NUM_TRAIN = 5;
    end
    properties
        % Stores the training images in columnised format. This is the
        % matrix X_i described in the paper.
        training;
        % Cached the values of the matrix H_i described in the paper.
        hats;
    end
    methods
        function obj = LRC(img_location)
            obj.training = obj.read_training_images(img_location);
            obj.hats = obj.compute_hat_matrices();
        end
        
        function lrc(obj, image)
            image = obj.preprocess_image(image);
            obj.hats * image
        end
        
        function [img] = preprocess_image(obj, img)
            % Resize image to the subsample size (defined as 10x5 in
            % the paper.
            img = imresize(img, obj.SUBSAMPLE_SIZE);
            % Columnise and convert to doubles.
            col_len = prod(obj.SUBSAMPLE_SIZE);
            img = double(reshape(img, col_len, 1));
            % Noramlise so the maximum component is 1.
            img = img / max(img);
        end
        function [hats] = compute_hat_matrices(obj)
            % Equivalent of X_i * (tranpose(X_i) * X_i) ^-1 *
            % transpose(X_i)
            hats = obj.training / (transpose(obj.training) * obj.training)...
                *transpose(obj.training);
        end
        function [training] = read_training_images(obj, location)
            % TODO: Read multiple directories.
            % For each training class, stores training images. Preallocate space.
            col_len = prod(obj.SUBSAMPLE_SIZE);
            % Store each image as a column.
            training = zeros([col_len obj.NUM_TRAIN]);
            for i = 1 : obj.NUM_TRAIN
                filename = sprintf('%s%d.pgm', location, i);
                imresize(imread(filename), obj.SUBSAMPLE_SIZE)
                % Read in and preprocess the image.
                training(:, i) = obj.preprocess_image(imread(filename));
            end
        end
    end
end
