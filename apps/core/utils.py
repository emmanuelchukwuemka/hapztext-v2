from nanoid import generate

def generate_nanoid(size=21, alphabet=None):
    if alphabet:
        return generate(alphabet=alphabet, size=size)
    return generate(size=size)
