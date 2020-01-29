#!/usr/bin/env python
'''
CodeCommit to CodeBuild Integration

Start CodeBuild jobs based on CodeCommit events.
'''


import json
import logging
import boto3

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

PROJECT_NAME = 'BlogCI'


def get_is_tag(ref):
    return 'tags' in ref


def submit_build(reference, project_name, region):
    '''Submit codebuild job for reference'''
    client = boto3.client('codebuild', region_name=region)

    response = client.start_build(
        projectName=project_name,
        sourceVersion=reference,
    )
    LOG.info(response['build'])


def debug_handler(detail):
    '''Log details and exit'''
    LOG.warn(detail)
    return True


def reference_change_handler(detail):
    '''handle reference change events, submitting code build jobs if needed'''
    references = detail['codecommit']['references']
    region = detail['awsRegion']
    for reference in references:
        is_deleted = reference.get('deleted', False)
        if is_deleted:
            continue
        if 'tags' in reference['ref']:
            submit_build(reference['ref'], PROJECT_NAME, region)
        else:
            submit_build(reference['commit'], PROJECT_NAME, region)


EVENT_HANDLERS = {
    'TriggerEventTest': False,
    'ReferenceChanges': reference_change_handler,
}


def handler(event, _context):
    '''Main Event Handler'''
    for message_record in event['Records']:
        records = json.loads(message_record['Sns']['Message'])
        for record in records['Records']:
            name = record['eventName']
            event_handler = EVENT_HANDLERS.get(name)
            if event_handler is False:
                return True
            elif event_handler is None:
                event_handler = debug_handler
            try:
                event_handler(record)
            except Exception as ex:
                LOG.error('Runtime exception occurred: %s', ex)

    return True
