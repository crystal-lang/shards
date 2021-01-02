def branch(name)
  Shards::GitBranchRef.new(name)
end

def commit(sha1)
  Shards::GitCommitRef.new(sha1)
end

def hg_branch(name)
  Shards::HgBranchRef.new(name)
end

def version(version)
  Shards::Version.new(version)
end

def versions(versions)
  versions.map { |v| version(v) }
end

def version_req(pattern)
  Shards::VersionReq.new(pattern)
end
