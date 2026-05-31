from time import perf_counter

def performance_timer(func):
    def wrapper(*args, **kwargs):
        start_time = perf_counter()
        result = func(*args, **kwargs)
        end_time = perf_counter()
        execution_time = end_time - start_time
        match execution_time:
            case execution_time < 1e3:
                print(f"[ {func.__name__} - Finished in {execution_time * 1e6: .3f}us ]")
            case execution_time < 1:
                print(f"[ {func.__name__} - Finished in {execution_time * 1e3: .3f}ms ]")
            case execution_time > 60:
                print(f"[ {func.__name__} - Finished in {execution_time / 60: .2f}min ]")
            case _:
                print(f"[ {func.__name__} - Finished in {execution_time: .3f}s ]")
        return result
    return wrapper

