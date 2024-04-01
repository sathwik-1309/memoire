class Lock
  def self.acquire_lock(key, expiration)
    $redis.set(key, 'locked', ex: expiration, nx: true)
  end

  def self.acquire_locks(key1, key2, expiration)
    lock2_acquired = false
    lock1_acquired = $redis.set(key1, 'locked', ex: expiration, nx: true)
    if lock1_acquired
      lock2_acquired = $redis.set(key2, 'locked', ex: expiration, nx: true)
    end

    unless lock1_acquired && lock2_acquired
      $redis.del(key1) if lock1_acquired
      $redis.del(key2) if lock2_acquired
    end

    lock1_acquired && lock2_acquired
  end

  def self.release_lock(key)
    $redis.del(key)
  end

  def self.release_locks(key1, key2)
    $redis.del(key1)
    $redis.del(key2)
  end

end