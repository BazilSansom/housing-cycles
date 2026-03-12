function h = sha256_file(fn)
%HS.DATA.SHA256_FILE  SHA-256 hash of a file as lowercase hex string (chunked).
%
% Much faster than byte-by-byte DigestInputStream.read() loops.

fid = fopen(fn, 'rb');
assert(fid>0, 'Could not open file: %s', fn);

cleanup = onCleanup(@() fclose(fid));

md = java.security.MessageDigest.getInstance('SHA-256');

chunkSize = 8 * 1024 * 1024;  % 8 MB
while true
    data = fread(fid, chunkSize, '*uint8');
    if isempty(data)
        break;
    end
    md.update(data);  % MATLAB passes uint8 vector to Java byte[]
end

hash = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(hash)', 1, []));
end