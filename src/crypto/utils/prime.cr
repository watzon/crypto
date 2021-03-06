require "big"
require "./math"

module Crypto
  INT_MAX = Int64::MAX

  #
  # The set of all prime numbers. Adapted from the Ruby implementation
  # at https://github.com/ruby/prime.
  #
  # ## Example
  #
  # ```
  # Prime.each(100) do |prime|
  #   p prime # => 2, 3, 5, 7, 11, ...., 97
  # end
  # ```
  #
  # Prime is Enumerable:
  #
  # ```
  # Prime.first 5 # => [2, 3, 5, 7, 11]
  # ```
  #
  # ## Generators
  #
  # A "generator" provides an implementation of enumerating pseudo-prime
  # numbers and it remembers the position of enumeration and upper bound.
  # Furthermore, it is an external iterator of prime enumeration which is
  # compatible with an Enumerator.
  #
  # `Prime::PseudoPrimeGenerator` is the base class for generators.
  # There are few implementations of generator.
  #
  # [`Prime::EratosthenesGenerator`]
  #   Uses Eratosthenes' sieve.
  # [`Prime::TrialDivisionGenerator`]
  #   Uses the trial division method.
  # [`Prime::Generator23`]
  #   Generates all positive integers which are not divisible by either 2 or 3.
  #   This sequence is very bad as a pseudo-prime sequence. But this
  #   is faster and uses much less memory than the other generators. So,
  #   it is suitable for factorizing an integer which is not large but
  #   has many prime factors. e.g. for `Prime#prime?`.
  class Prime
    include Enumerable(Int::Signed)

    # Iterates the given block over all prime numbers.
    #
    # ## Parameters
    #
    # `ubound`:
    #   Optional. An arbitrary positive number.
    #   The upper bound of enumeration. The method enumerates
    #   prime numbers infinitely if `ubound` is nil.
    # `generator`:
    #   Optional. An implementation of pseudo-prime generator.
    #
    # ## Return value
    #
    # An evaluated value of the given block at the last time.
    # Or an enumerator which is compatible to an `Enumerator`
    # if no block given.
    #
    # ## Description
    #
    # Calls `block` once for each prime number, passing the prime as
    # a parameter.
    #
    # `ubound`:
    #   Upper bound of prime numbers. The iterator stops after it
    #   yields all prime numbers `p <= ubound`.
    #
    def self.each(ubound = nil, generator = EratosthenesGenerator.new, &block : Int::Signed ->)
      generator.upper_bound = ubound
      generator.each { |i| yield i }
    end

    # see `.each`
    def each(ubound = nil, generator = EratosthenesGenerator.new, &block : Int::Signed ->)
      generator.upper_bound = ubound
      generator.each { |i| yield i }
    end

    # def find(if_none = nil, &block : Int::Signed -> Bool)
    #   res = nil
    #   each do |elem|
    #     if block.call(elem)
    #       res = elem
    #       raise
    #     end
    #   end
    # rescue
    #   res || if_none
    # end

    # Returns true if `value` is a prime number, else returns false.
    #
    # == Parameters
    #
    # `value`: an arbitrary integer to be checked.
    def self.prime?(n, k = 10)
      n = n.to_big_i
      neg_one_mod = d = n - 1
      s = 0.to_big_i
      while d.even?
        d >>= 1; s += 1
      end # d is odd after s shifts
      k.times do
        b = rand(n - 4) + 2      # random witness base b
        y = Math.modpow(b, d, n) # y = (b**d) mod n
        next if y == 1 || y == neg_one_mod
        (s - 1).times do
          y = (y.to_big_i * y) % n # y = (y**2) mod n
          return false if y == 1
          break if y == neg_one_mod
        end
        return false if y != neg_one_mod
      end
      true # prime (with high probability)
    end

    # see `.prime?`
    def prime?(n, k = 10)
      Prime.prime(n, k)
    end

    # Re-composes a prime factorization and returns the product.
    #
    # For the decomposition:
    #
    # ```
    #   [[p_1, e_1], [p_2, e_2], ..., [p_n, e_n]],
    # ```
    #
    # it returns:
    #
    # ```
    #   p_1**e_1 * p_2**e_2 * ... * p_n**e_n.
    # ```
    #
    # ## Parameters
    # `pd`: Array of pairs of integers.
    #        Each pair consists of a prime number -- a prime factor --
    #        and a natural number -- its exponent (multiplicity).
    #
    # ## Example
    #
    # ```
    # Prime.int_from_factorization([[3, 2], [5, 1]]) # => 45
    # 3**2 * 5                                       # => 45
    # ```
    #
    def self.int_from_factorization(pd : Indexable(Indexable(Int)))
      pd.reduce(1) do |value, (prime, index)|
        value * prime**index
      end
    end

    # see `.int_from_factorization`
    def int_from_factorization(pd : Indexable(Indexable(Int)))
      Prime.int_from_factorization(pd)
    end

    # Returns the factorization of `value`.
    #
    # For an arbitrary integer:
    #
    # ```
    # p_1**e_1 * p_2**e_2 * ... * p_n**e_n,
    # ``
    #
    # factorize returns an array of pairs of integers:
    #
    # ```
    # [[p_1, e_1], [p_2, e_2], ..., [p_n, e_n]].
    # ```
    #
    # Each pair consists of a prime number -- a prime factor --
    # and a natural number -- its exponent (multiplicity).
    #
    # ## Parameters
    # `value`: An arbitrary integer.
    # `generator`: Optional. A pseudo-prime generator.
    #              `generator`.succ must return the next
    #              pseudo-prime number in ascending order.
    #              It must generate all prime numbers,
    #              but may also generate non-prime numbers, too.
    #
    # ### Exceptions
    # `DivisionByZeroError`: when `value` is zero.
    #
    # ## Example
    #
    # ```
    # Prime.factorize(45)  #=> [[3, 2], [5, 1]]
    # 3**2 * 5                  #=> 45
    # ```
    #
    def self.factorize(value, generator = Generator23.new)
      raise DivisionByZeroError.new if value == 0
      pv = [] of Array(Int::Signed)

      if value < 0
        value = -value
        pv.push [-1, 1]
      end

      generator.each do |prime|
        count = 0
        mod = 0

        while mod.zero?
          value1, mod = value.divmod(prime)
          break unless mod.zero?
          value = value1
          count += 1
        end

        if count != 0
          pv.push [prime, count]
        end

        break if !value1.nil? && value1 <= prime
      end

      if value > 1
        pv.push [value, 1]
      end

      pv
    end

    # see `.factorize`
    def factorize(value, generator = Generator23.new)
      Prime.factorize(value, generator)
    end

    # Returns `true` if the integer `a` is coprime (relatively prime) to
    # integer `b`.
    #
    # Example
    # ```
    # RSA::Math.coprime?(6, 35) # => true
    # RSA::Math.coprime?(6, 27) # => false
    # ```
    #
    def self.coprime?(a, b)
      egcd = Math.egcd(a, b)
      (a * egcd[0] + b * egcd[1]) == 1
    end

    # Return `count` random primes in the given range.
    def self.random(start, stop, count, generator = Generator23.new, random = Random::DEFAULT)
      values = [] of Int::Signed

      self.each(stop, generator) do |i|
        if i >= start
          values << i
        end
      end

      values.sample(count, random)
    end

    def self.random(bits, random = Random::DEFAULT)
      loop do
        int = self.random_odd_int(bits, random)
        if self.prime?(int)
          return int
        end
      end
    end

    # see `.random`
    def random(start, stop, count, generator = Generator23.new, random = Random::DEFAULT)
      Prime.random(start, stop, count, generator, random)
    end

    def random(bits, random = Random::DEFAULT)
      Prime.random(bits, random)
    end

    private def self.random_odd_int(bits, random = Random::DEFAULT)
      bytes = random.random_bytes(bits < 8 ? 1 : bits // 8)
      IO::ByteFormat::LittleEndian.decode(UInt64, bytes) | 1
    end

    # An abstract class for enumerating pseudo-prime numbers.
    #
    # Concrete subclasses should override succ, next, rewind.
    abstract class PseudoPrimeGenerator
      include Enumerable(Int::Signed)
      include Iterator(Int::Signed)

      @ubound : Int::Signed?

      def initialize(@ubound = nil)
      end

      def upper_bound=(ubound)
        @ubound = ubound
      end

      def upper_bound
        @ubound
      end

      # returns the next pseudo-prime number, and move the internal
      # position forward.
      #
      abstract def succ : Int::Signed

      # Rewinds the internal position for enumeration.
      #
      abstract def rewind : self

      # alias of `succ`.
      def next
        succ
      end

      # Iterates the given block for each prime number.
      def each
        if ubound = @ubound
          last_value = 0
          loop do
            prime = succ
            if prime > ubound
              break last_value
            end
            last_value = yield prime
          end
        else
          loop do
            next_val = succ
            yield succ
          end
        end
      rescue OverflowError
      end

      def size
        Float::INFINITY
      end
    end

    # An implementation of `PseudoPrimeGenerator`.
    #
    # Uses `EratosthenesSieve`.
    class EratosthenesGenerator < PseudoPrimeGenerator
      @last_prime_index : Int::Signed
      @internal : EratosthenesSieve

      def initialize
        @last_prime_index = -1
        @internal = EratosthenesSieve.new
        super
      end

      def succ : Int::Signed
        @last_prime_index += 1
        @internal.get_nth_prime(@last_prime_index)
      end

      def rewind : self
        initialize
      end
    end

    # An implementation of `PseudoPrimeGenerator` which uses
    # a prime table generated by trial division.
    class TrialDivisionGenerator < PseudoPrimeGenerator
      @index : Int::Signed
      @internal : TrialDivision

      def initialize
        @index = -1
        @internal = TrialDivision.new
        super
      end

      def succ : Int::Signed
        @internal[@index += 1]
      end

      def rewind : self
        initialize
      end
    end

    # Generates all integers which are greater than 2 and
    # are not divisible by either 2 or 3.
    #
    # This is a pseudo-prime generator, suitable on
    # checking primality of an integer by brute force
    # method.
    class Generator23 < PseudoPrimeGenerator
      @prime : Int::Signed
      @step : Int::Signed?

      def initialize(ubound = nil)
        @prime = 1
        @step = nil
        super(ubound)
      end

      def succ : Int::Signed
        if (step = @step)
          @prime += step
          @step = 6 - step
        else
          case @prime
          when 1; @prime = 2
          when 2; @prime = 3
          when 3; @prime = 5; @step = 2
          end
        end
        @prime
      end

      def rewind : self
        initialize
      end
    end

    # Internal use. An implementation of prime table by trial division method.
    private class TrialDivision
      @primes : Array(Int::Signed)
      @next_to_check : Int::Signed
      @ulticheck_index : Int::Signed
      @ulticheck_next_squared : Int::Signed

      def initialize
        # These are included as class variables to cache them for later uses.  If memory
        #   usage is a problem, they can be put in Prime#initialize as instance variables.

        @primes = [] of Int::Signed
        # There must be no primes between @primes[-1] and @next_to_check.
        @primes.concat([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101])
        # @next_to_check % 6 must be 1.
        @next_to_check = 103 # @primes[-1] - @primes[-1] % 6 + 7
        @ulticheck_index = 3 # @primes.index(@primes.reverse.find {|n|
        #   n < Math.sqrt(@@next_to_check) })
        @ulticheck_next_squared = 121 # @primes[@ulticheck_index + 1] ** 2
      end

      # Returns the `index`th prime number.
      #
      # `index` is a 0-based index.
      def [](index)
        while index >= @primes.size
          # Only check for prime factors up to the square root of the potential primes,
          #   but without the performance hit of an actual square root calculation.
          if @next_to_check + 4 > @ulticheck_next_squared
            @ulticheck_index += 1
            @ulticheck_next_squared = @primes[@ulticheck_index + 1] ** 2
          end
          # Only check numbers congruent to one and five, modulo six. All others

          #   are divisible by two or three.  This also allows us to skip checking against
          #   two and three.
          @primes.push @next_to_check if @primes[2..@ulticheck_index].find { |prime| @next_to_check % prime == 0 }.nil?
          @next_to_check += 4
          @primes.push @next_to_check if @primes[2..@ulticheck_index].find { |prime| @next_to_check % prime == 0 }.nil?
          @next_to_check += 2
        end
        @primes[index]
      end
    end

    # Internal use. An implementation of Eratosthenes' sieve
    private class EratosthenesSieve
      @primes : Array(Int::Signed)
      @max_checked : Int::Signed

      def initialize
        @primes = [] of Int::Signed
        @primes.concat([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101])
        # @max_checked must be an even number
        @max_checked = @primes.last + 1
      end

      def get_nth_prime(n)
        while @primes.size <= n
          compute_primes
        end
        @primes[n]
      end

      private def compute_primes
        # max_segment_size must be an even number
        max_segment_size = 1e6.to_i
        max_cached_prime = @primes.last

        # do not double count primes if #compute_primes is interrupted
        @max_checked = max_cached_prime + 1 if max_cached_prime > @max_checked

        segment_min = @max_checked
        segment_max = [segment_min + max_segment_size, max_cached_prime * 2].min
        root = Math.sqrt(segment_max)

        segment = [] of Int::Signed | Nil
        segment.concat(((segment_min + 1)..segment_max).step(2).to_a)

        (1..Float64::INFINITY).each do |sieving|
          prime = @primes[sieving]
          break if prime > root
          composite_index = (-(segment_min + 1 + prime) // 2) % prime
          while composite_index < segment.size
            segment[composite_index] = nil
            composite_index += prime
          end
        end

        @primes.concat(segment.compact)
        @max_checked = segment_max
      end
    end
  end
end
