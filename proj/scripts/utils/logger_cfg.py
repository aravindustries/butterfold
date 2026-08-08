import logging
import logging.config
import json

logger = logging.getLogger("Main")

class Whitelist(logging.Filter):
    def __init__(self, *whitelist):
        self.whitelist = [logging.Filter(name) for name in whitelist]
    def filter(self, record):
        return any(f.filter(record) for f in self.whitelist)

with open("logging_config.json", 'r') as file_handle:
    config_dict = json.load(file_handle)

config_dict["loggers"]["root"]["handlers"].append("stdout")
config_dict["handlers"]["stdout"]["level"] = "WARNING"
logging.config.dictConfig(config_dict)
# logging.root.handlers[-1].addFilter(Whitelist("Main"))

logger.warning("Something here too")

