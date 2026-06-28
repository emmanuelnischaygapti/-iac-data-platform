# AWS Lambda Python base image — identical runtime to what runs in the cloud.
# Using the official AWS image guarantees no "works locally, fails in Lambda" surprises.
FROM public.ecr.aws/lambda/python:3.12

# Copy requirements first so Docker layer cache is reused on code-only changes.
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

COPY etl_transform.py ${LAMBDA_TASK_ROOT}/

# The handler string matches: filename.function_name
CMD ["etl_transform.lambda_handler"]
