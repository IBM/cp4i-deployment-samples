from collections.abc import Sequence, Mapping, Callable
from dataclasses import dataclass, field
from typing import Optional


@dataclass(eq=False)
class Table(Mapping):
    """ Virtual Table for storing records
        Implementation follows dict conventions and can be
        used as a regular dictionary. Table provides get_random()
        for retrieving random entries to the table
        All data inputs to the table should be stored as dictionaries
        Args:
            random_number_generator: A callable random number generator
            keep_fields: The list of field to keep from the input dictionary
            table: A pre-populated table can be provided
            auto_clear: Clears the table whenever there are > 1,000 records
                        to conserve memory. Disable this if you would like
                        to keep all data in the table.
    """

    random_number_generator: Callable
    keep_fields: Optional[Sequence[str]] = field(default_factory=list)
    table: Optional[dict] = field(default_factory=dict)
    auto_clear: Optional[bool] = True

    def get_random_key(self) -> str:
        """ Get a random ID from the table to fulfill a GET or DELETE
            request. For requests that require the original data
            e.g. PUT, use get_random_row() instead
        """
        random_record = self.random_number_generator(len(self.table))
        return list(self.table.keys())[random_record]

    def get_random_row(self) -> tuple[str, dict]:
        rand_key = self.get_random_key()
        return rand_key, self.table[rand_key].copy()

    def remove(self, key):
        self.__delitem__(key)

    def reset(self):
        """ Use to clear a Table
            Tables will be cleared automatically when a limit of 1,000
            rows has been reached to conserve memory
        """
        self.table.clear()

    def _extract_fields(self, key, data) -> tuple[str, dict]:
        fields_to_keep = {name: value for name, value in data.items() if name in self.keep_fields}
        return key, fields_to_keep

    def __getitem__(self, item):
        return self.table[item]

    def __setitem__(self, key, value):
        if len(self.table) > 1000:
            self.reset()
        if self.keep_fields and isinstance(value, dict):
            key, value = self._extract_fields(key, value)

        self.table[key] = value

    def __delitem__(self, key):
        self.table.pop(key, None)

    def __iter__(self):
        return iter(self.table)

    def __len__(self):
        return len(self.table)

    def __bool__(self):
        return len(self.table) != 0
